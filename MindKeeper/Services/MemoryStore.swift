import Foundation
import SwiftData

@MainActor
final class MemoryStore {
    private var modelContext: ModelContext?

    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }

    func recordAction(_ action: TaskAction, for task: TaskItem) {
        guard let context = modelContext else { return }

        if let bundleId = task.appBundleId {
            updateMemory(dimension: "source", key: bundleId, action: action, in: context)
        }
        if let sender = task.sender {
            updateMemory(dimension: "sender", key: sender, action: action, in: context)
        }
        if let category = task.category {
            updateMemory(dimension: "category", key: category.rawValue, action: action, in: context)
        }

        let hourSlot = Calendar.current.component(.hour, from: Date())
        let timeKey = "\(hourSlot / 4)"
        updateMemory(dimension: "timeSlot", key: timeKey, action: action, in: context)

        try? context.save()
    }

    func buildContext(for task: TaskItem) -> String {
        guard let context = modelContext else { return "" }
        var parts: [String] = []

        if let bundleId = task.appBundleId,
           let mem = fetchMemory(dimension: "source", key: bundleId, in: context) {
            parts.append("来源[\(task.appName ?? bundleId)]: 完成率\(pct(mem.completionRate)), 丢弃率\(pct(mem.dropRate))")
        }

        if let sender = task.sender,
           let mem = fetchMemory(dimension: "sender", key: sender, in: context) {
            parts.append("发送人[\(sender)]: 完成率\(pct(mem.completionRate)), 丢弃率\(pct(mem.dropRate))")
        }

        if let category = task.category,
           let mem = fetchMemory(dimension: "category", key: category.rawValue, in: context) {
            parts.append("类型[\(category.displayName)]: 完成率\(pct(mem.completionRate)), 丢弃率\(pct(mem.dropRate))")
        }

        return parts.isEmpty ? "" : parts.joined(separator: "\n")
    }

    // MARK: - Private

    private func updateMemory(dimension: String, key: String, action: TaskAction, in context: ModelContext) {
        let mem = fetchOrCreate(dimension: dimension, key: key, in: context)
        mem.totalCount += 1
        mem.updatedAt = Date()

        switch action {
        case .completed: mem.completedCount += 1
        case .dropped: mem.droppedCount += 1
        case .deferred: mem.deferredCount += 1
        case .expired: mem.expiredCount += 1
        }
    }

    private func fetchMemory(dimension: String, key: String, in context: ModelContext) -> UserMemory? {
        let predicate = #Predicate<UserMemory> { $0.dimension == dimension && $0.key == key }
        let descriptor = FetchDescriptor(predicate: predicate)
        return try? context.fetch(descriptor).first
    }

    private func fetchOrCreate(dimension: String, key: String, in context: ModelContext) -> UserMemory {
        if let existing = fetchMemory(dimension: dimension, key: key, in: context) {
            return existing
        }
        let mem = UserMemory(dimension: dimension, key: key)
        context.insert(mem)
        return mem
    }

    private func pct(_ value: Double) -> String {
        String(format: "%.0f%%", value * 100)
    }
}

enum TaskAction: Sendable {
    case completed, dropped, deferred, expired
}
