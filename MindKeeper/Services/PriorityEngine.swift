import Foundation
import SwiftData

@MainActor
final class PriorityEngine {
    private let llmService: LLMService
    private let memoryStore: MemoryStore

    init(llmService: LLMService, memoryStore: MemoryStore) {
        self.llmService = llmService
        self.memoryStore = memoryStore
    }

    func evaluate(_ task: TaskItem) async {
        let snapshot = task.snapshot
        let memoryContext = memoryStore.buildContext(for: task)

        if let classification = await llmService.classify(snapshot, memoryContext: memoryContext) {
            applyClassification(classification, to: task)
        }

        let factors = computeFactors(task)
        task.priority = computeScore(factors)
    }

    func sortByPriority(_ tasks: inout [TaskItem]) {
        tasks.sort { $0.priority > $1.priority }
    }

    private func applyClassification(_ c: LLMClassification, to task: TaskItem) {
        task.category = TaskCategory(rawValue: c.category)
        task.urgency = c.urgency.clamped(to: 1...10)
        task.importance = c.importance.clamped(to: 1...10)
        task.llmReason = c.reason
        task.suggestedAction = c.suggestedAction
    }

    private func computeFactors(_ task: TaskItem) -> PriorityFactors {
        PriorityFactors(
            urgency: Double(task.urgency),
            importance: Double(task.importance),
            contextBoost: contextBoost(task),
            freshnessDecay: freshnessDecay(task),
            keywordBoost: keywordBoost(task)
        )
    }

    private func computeScore(_ f: PriorityFactors) -> Double {
        let raw = f.urgency * 0.35
            + f.importance * 0.30
            + f.contextBoost * 0.15
            + f.freshnessDecay * 0.10
            + f.keywordBoost * 0.10
        return raw.clamped(to: 0...10)
    }

    private func contextBoost(_ task: TaskItem) -> Double {
        var boost = 5.0
        let hour = Calendar.current.component(.hour, from: Date())
        let isWorkHours = (9...18).contains(hour)
        if task.category == .work && isWorkHours { boost += 2 }
        if task.category == .social && !isWorkHours { boost += 1 }
        return boost.clamped(to: 0...10)
    }

    private func freshnessDecay(_ task: TaskItem) -> Double {
        let ageHours = task.ageSinceCreation / 3600
        switch ageHours {
        case ..<1: return 8
        case ..<6: return 6
        case ..<24: return 4
        default: return 2
        }
    }

    private func keywordBoost(_ task: TaskItem) -> Double {
        let urgentKeywords = ["紧急", "urgent", "asap", "deadline", "马上", "立即", "@"]
        let text = (task.title + " " + task.body).lowercased()
        return urgentKeywords.contains(where: { text.contains($0) }) ? 8 : 5
    }
}

private struct PriorityFactors {
    let urgency: Double
    let importance: Double
    let contextBoost: Double
    let freshnessDecay: Double
    let keywordBoost: Double
}

extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
