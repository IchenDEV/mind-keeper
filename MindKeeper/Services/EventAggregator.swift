import Foundation

@MainActor
final class EventAggregator {
    private let llmService: LLMService

    init(llmService: LLMService) {
        self.llmService = llmService
    }

    struct AggregationResult {
        let matchedTask: TaskItem?
        let shouldMerge: Bool
    }

    func findMatch(
        for record: NotificationRecord,
        in pendingTasks: [TaskItem]
    ) async -> AggregationResult {
        let activeTasks = pendingTasks.filter { $0.status == .pending }
        guard !activeTasks.isEmpty else {
            return AggregationResult(matchedTask: nil, shouldMerge: false)
        }

        if let fastMatch = fastMatch(for: record, in: activeTasks) {
            return AggregationResult(matchedTask: fastMatch, shouldMerge: true)
        }

        return await llmMatch(for: record, in: activeTasks)
    }

    private func fastMatch(for record: NotificationRecord, in tasks: [TaskItem]) -> TaskItem? {
        for task in tasks {
            if !record.bundleId.isEmpty && task.appBundleId == record.bundleId {
                if hasSimilarContent(task: task, record: record) {
                    return task
                }
            }
        }
        return nil
    }

    private func hasSimilarContent(task: TaskItem, record: NotificationRecord) -> Bool {
        let taskWords = extractKeywords(task.title + " " + task.body)
        let recordWords = extractKeywords(record.title + " " + record.body)
        guard !taskWords.isEmpty, !recordWords.isEmpty else { return false }

        let overlap = taskWords.intersection(recordWords)
        let similarity = Double(overlap.count) / Double(min(taskWords.count, recordWords.count))
        return similarity >= 0.4
    }

    private func extractKeywords(_ text: String) -> Set<String> {
        let stopWords: Set<String> = [
            "的", "了", "是", "在", "有", "和", "与", "a", "the", "is", "to", "in",
            "for", "on", "at", "by", "an", "you", "your", "this", "that"
        ]
        let words = text.components(separatedBy: .whitespacesAndNewlines)
            .flatMap { $0.components(separatedBy: .punctuationCharacters) }
            .map { $0.lowercased() }
            .filter { $0.count > 1 && !stopWords.contains($0) }
        return Set(words)
    }

    private let maxPromptTasks = 15

    private func llmMatch(
        for record: NotificationRecord,
        in tasks: [TaskItem]
    ) async -> AggregationResult {
        let promptTasks = Array(tasks.prefix(maxPromptTasks))
        let tasksContext = promptTasks.enumerated().map { idx, task in
            "[\(idx)] \(task.title) | \(task.body.prefix(60))"
        }.joined(separator: "\n")

        let newNotif = "标题: \(record.title)\n内容: \(record.body)\n来源: \(record.appName)"

        let prompt = """
        判断新通知是否属于已有事务中的某一件。如果属于，返回事务编号；否则返回 -1。
        只返回 JSON: {"match_index": 0} 或 {"match_index": -1}
        
        已有事务列表:
        \(tasksContext)
        
        新通知:
        \(newNotif)
        """

        guard let result = await callLLMForAggregation(prompt) else {
            return AggregationResult(matchedTask: nil, shouldMerge: false)
        }

        if result >= 0, result < promptTasks.count {
            return AggregationResult(matchedTask: promptTasks[result], shouldMerge: true)
        }
        return AggregationResult(matchedTask: nil, shouldMerge: false)
    }

    private func callLLMForAggregation(_ prompt: String) async -> Int? {
        guard let raw = await llmService.rawQuery(prompt) else { return nil }

        let cleaned = raw
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let data = cleaned.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let idx = json["match_index"] as? Int {
            return idx
        }

        if let range = cleaned.range(of: #"-?\d+"#, options: .regularExpression) {
            return Int(cleaned[range])
        }
        return nil
    }

    func mergeIntoTask(_ task: TaskItem, from record: NotificationRecord) {
        task.mergeNotification(
            title: record.title,
            body: record.body,
            sender: nil
        )

        if task.ageSinceCreation < 3600 {
            task.urgency = min(task.urgency + 1, 10)
        }
    }
}
