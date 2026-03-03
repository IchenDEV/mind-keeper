import Foundation
import SwiftData

struct ExpiryConfig {
    var notificationAgingHours: Double
    var notificationExpiredHours: Double
    var manualAgingDays: Double
    var manualExpiredDays: Double
    var deferReentryHours: Double

    static var fromUserDefaults: ExpiryConfig {
        let d = UserDefaults.standard
        return ExpiryConfig(
            notificationAgingHours: d.object(forKey: "notifAgingHours") as? Double ?? 24,
            notificationExpiredHours: d.object(forKey: "notifExpiredHours") as? Double ?? 72,
            manualAgingDays: d.object(forKey: "manualAgingDays") as? Double ?? 7,
            manualExpiredDays: d.object(forKey: "manualExpiredDays") as? Double ?? 14,
            deferReentryHours: 12
        )
    }

    static let `default` = ExpiryConfig(
        notificationAgingHours: 24, notificationExpiredHours: 72,
        manualAgingDays: 7, manualExpiredDays: 14, deferReentryHours: 12
    )
}

struct ExpiryManager {
    let config: ExpiryConfig

    init(config: ExpiryConfig = .default) {
        self.config = config
    }

    func processExpiry(_ tasks: [TaskItem]) -> ExpiryResult {
        var aged: [TaskItem] = []
        var expired: [TaskItem] = []
        var reentry: [TaskItem] = []

        for task in tasks {
            switch task.status {
            case .pending:
                if let newStatus = checkAge(task) {
                    if newStatus == .aging { aged.append(task) }
                    else if newStatus == .expired { expired.append(task) }
                    task.status = newStatus
                }

            case .deferred:
                if shouldReenter(task) {
                    task.status = .pending
                    reentry.append(task)
                } else if let newStatus = checkAge(task) {
                    if newStatus == .expired { expired.append(task) }
                    task.status = newStatus
                }

            default:
                break
            }
        }

        return ExpiryResult(aged: aged, expired: expired, reentered: reentry)
    }

    private func checkAge(_ task: TaskItem) -> TaskStatus? {
        let ageHours = task.ageSinceCreation / 3600

        let (agingThreshold, expiredThreshold) = thresholds(for: task)

        let deferMultiplier = max(1.0 / pow(2.0, Double(task.deferCount)), 0.125)
        let adjustedAging = agingThreshold * deferMultiplier
        let adjustedExpired = expiredThreshold * deferMultiplier

        if ageHours >= adjustedExpired { return .expired }
        if ageHours >= adjustedAging { return .aging }
        return nil
    }

    private func thresholds(for task: TaskItem) -> (aging: Double, expired: Double) {
        switch task.source {
        case .notification:
            return (config.notificationAgingHours, config.notificationExpiredHours)
        case .manual:
            return (config.manualAgingDays * 24, config.manualExpiredDays * 24)
        }
    }

    private func shouldReenter(_ task: TaskItem) -> Bool {
        guard let lastDeferred = task.lastDeferredAt else { return false }
        let hoursSinceDefer = Date().timeIntervalSince(lastDeferred) / 3600
        return hoursSinceDefer >= config.deferReentryHours
    }
}

struct ExpiryResult {
    let aged: [TaskItem]
    let expired: [TaskItem]
    let reentered: [TaskItem]

    var hasChanges: Bool {
        !aged.isEmpty || !expired.isEmpty || !reentered.isEmpty
    }
}
