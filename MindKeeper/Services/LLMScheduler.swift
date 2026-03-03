import Foundation

struct ScheduleResult: Codable, Sendable {
    let orderedIds: [String]
    let urgentIds: [String]
    let reason: String

    enum CodingKeys: String, CodingKey {
        case orderedIds = "ordered_ids"
        case urgentIds = "urgent_ids"
        case reason
    }
}

@MainActor
final class LLMScheduler {
    private let llmService: LLMService
    private let priorityEngine: PriorityEngine

    init(llmService: LLMService, priorityEngine: PriorityEngine) {
        self.llmService = llmService
        self.priorityEngine = priorityEngine
    }

    func reschedule(_ tasks: inout [TaskItem]) async {
        guard !tasks.isEmpty else { return }

        if let result = await llmReorder(tasks) {
            applyScheduleResult(result, to: &tasks)
        } else {
            fallbackReschedule(&tasks)
        }
    }

    func evaluateAndInsert(
        newTask: TaskItem,
        into tasks: inout [TaskItem],
        memoryContext: String
    ) async {
        let snapshot = newTask.snapshot
        if let classification = await llmService.classify(snapshot, memoryContext: memoryContext) {
            newTask.category = TaskCategory(rawValue: classification.category)
            newTask.urgency = classification.urgency.clamped(to: 1...10)
            newTask.importance = classification.importance.clamped(to: 1...10)
            newTask.llmReason = classification.reason
            newTask.suggestedAction = classification.suggestedAction

            if classification.urgency >= 9 || isUrgentFromAction(classification.suggestedAction) {
                newTask.isUrgent = true
            }
        }

        detectUrgentByKeywords(newTask)

        let factors = computePriority(newTask)
        newTask.priority = factors

        if newTask.isUrgent {
            tasks.insert(newTask, at: 0)
        } else {
            let idx = tasks.firstIndex { $0.priority < newTask.priority } ?? tasks.endIndex
            tasks.insert(newTask, at: idx)
        }
    }

    // MARK: - LLM Full Reorder

    private func llmReorder(_ tasks: [TaskItem]) async -> ScheduleResult? {
        let tasksSummary = tasks.prefix(20).map { task in
            let id = task.id.uuidString.prefix(8)
            let age = task.createdAt.relativeDisplay
            let urgLabel = task.isUrgent ? " [紧急]" : ""
            return "[\(id)] P\(String(format: "%.1f", task.priority))\(urgLabel) \(task.title) (\(task.appName ?? "手动"), \(age))"
        }.joined(separator: "\n")

        let prompt = """
        你是任务调度引擎。根据当前时间 \(formattedNow()) 重新排列任务优先级。
        规则:
        1. 有截止时间的任务越临近越优先
        2. 高紧急度+高重要度的排前面
        3. 频繁被通知的事情提高优先级
        4. 系统更新类低优先级
        5. 标记特别紧急的任务 ID

        当前任务:
        \(tasksSummary)

        返回 JSON: {"ordered_ids":["id1","id2"],"urgent_ids":["id"],"reason":"调度依据"}
        只返回 JSON。
        """

        guard let raw = await llmService.rawQuery(prompt) else { return nil }

        let cleaned = raw
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleaned.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(ScheduleResult.self, from: data)
    }

    private func applyScheduleResult(_ result: ScheduleResult, to tasks: inout [TaskItem]) {
        for id in result.urgentIds {
            if let task = tasks.first(where: { $0.id.uuidString.hasPrefix(id) }) {
                task.isUrgent = true
                task.urgency = max(task.urgency, 9)
            }
        }

        let lookup = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id.uuidString, $0) })
        var reordered: [TaskItem] = []
        var used = Set<String>()

        for id in result.orderedIds {
            if let match = lookup.first(where: { $0.key.hasPrefix(id) }) {
                reordered.append(match.value)
                used.insert(match.key)
            }
        }

        for task in tasks where !used.contains(task.id.uuidString) {
            reordered.append(task)
        }

        tasks = reordered
    }

    // MARK: - Fallback (no LLM)

    private func fallbackReschedule(_ tasks: inout [TaskItem]) {
        for task in tasks {
            detectUrgentByKeywords(task)
            task.priority = computePriority(task)
        }

        tasks.sort { lhs, rhs in
            if lhs.isUrgent != rhs.isUrgent { return lhs.isUrgent }
            return lhs.priority > rhs.priority
        }
    }

    private func detectUrgentByKeywords(_ task: TaskItem) {
        let text = (task.title + " " + task.body).lowercased()
        let urgentKeywords = ["紧急", "urgent", "asap", "立刻", "马上", "deadline", "immediately", "critical"]
        if urgentKeywords.contains(where: { text.contains($0) }) {
            task.isUrgent = true
            task.urgency = max(task.urgency, 9)
        }
        if task.urgency >= 9 && task.importance >= 8 {
            task.isUrgent = true
        }
    }

    private func isUrgentFromAction(_ action: String) -> Bool {
        action == "respond"
    }

    private func computePriority(_ task: TaskItem) -> Double {
        let ageHours = task.ageSinceCreation / 3600
        let freshness: Double = switch ageHours {
        case ..<1: 8
        case ..<6: 6
        case ..<24: 4
        default: 2
        }

        let aggregationBoost = min(Double(task.notificationCount - 1) * 0.5, 2.0)

        let raw = Double(task.urgency) * 0.35
            + Double(task.importance) * 0.30
            + freshness * 0.10
            + (task.isUrgent ? 10 : 5) * 0.15
            + aggregationBoost
            + keywordBoost(task) * 0.10

        return min(max(raw, 0), 10)
    }

    private func keywordBoost(_ task: TaskItem) -> Double {
        let text = (task.title + " " + task.body).lowercased()
        let keywords = ["紧急", "urgent", "asap", "deadline", "马上", "立即", "@"]
        return keywords.contains(where: { text.contains($0) }) ? 8 : 5
    }

    private func formattedNow() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm (EEEE)"
        f.locale = Locale(identifier: "zh_CN")
        return f.string(from: Date())
    }
}
