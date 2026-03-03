import Foundation
import SwiftUI
import SwiftData

enum PopoverPanel {
    case cardStack
    case addTask
    case cleanup
    case history
    case settings
    case onboarding
}

@MainActor @Observable
final class AppState {
    var activePanel: PopoverPanel = .cardStack
    var pendingTasks: [TaskItem] = []
    var expiredTasks: [TaskItem] = []
    var deferredTasks: [TaskItem] = []
    var completedTasks: [TaskItem] = []
    var droppedTasks: [TaskItem] = []

    var isOllamaAvailable = false
    var hasFullDiskAccess = false

    var badgeCount: Int { pendingTasks.count }
    var expiredBadgeCount: Int { expiredTasks.count }
    var historyBadgeCount: Int { deferredTasks.count }
    var hasUrgentTask: Bool { pendingTasks.contains { $0.isUrgent } }

    let memoryStore = MemoryStore()

    func markCompleted(_ task: TaskItem) {
        task.status = .completed
        task.processedAt = Date()
        removeFromPending(task)
        completedTasks.insert(task, at: 0)
        memoryStore.recordAction(.completed, for: task)
    }

    func markDropped(_ task: TaskItem) {
        task.status = .dropped
        task.processedAt = Date()
        removeFromPending(task)
        droppedTasks.insert(task, at: 0)
        memoryStore.recordAction(.dropped, for: task)
    }

    func markDeferred(_ task: TaskItem) {
        task.status = .deferred
        task.deferCount += 1
        task.lastDeferredAt = Date()
        removeFromPending(task)
        deferredTasks.insert(task, at: 0)
        memoryStore.recordAction(.deferred, for: task)
    }

    func requeueDeferred(_ task: TaskItem) {
        task.status = .pending
        deferredTasks.removeAll { $0.id == task.id }
        pendingTasks.insert(task, at: 0)
    }

    func dropDeferred(_ task: TaskItem) {
        task.status = .dropped
        task.processedAt = Date()
        deferredTasks.removeAll { $0.id == task.id }
        droppedTasks.insert(task, at: 0)
        memoryStore.recordAction(.dropped, for: task)
    }

    func requeueFromHistory(_ task: TaskItem) {
        task.status = .pending
        task.processedAt = nil
        completedTasks.removeAll { $0.id == task.id }
        droppedTasks.removeAll { $0.id == task.id }
        pendingTasks.insert(task, at: 0)
    }

    func addTask(_ task: TaskItem) {
        pendingTasks.insert(task, at: 0)
    }

    func runExpiryCheck() {
        let allTasks = pendingTasks + deferredTasks
        let manager = ExpiryManager(config: .fromUserDefaults)
        let result = manager.processExpiry(allTasks)

        if result.hasChanges {
            for task in result.expired {
                removeFromPending(task)
                deferredTasks.removeAll { $0.id == task.id }
                expiredTasks.append(task)
                memoryStore.recordAction(.expired, for: task)
            }
            for task in result.reentered {
                deferredTasks.removeAll { $0.id == task.id }
                if !pendingTasks.contains(where: { $0.id == task.id }) {
                    pendingTasks.append(task)
                }
            }
        }
    }

    private func removeFromPending(_ task: TaskItem) {
        pendingTasks.removeAll { $0.id == task.id }
    }
}
