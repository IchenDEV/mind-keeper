import Foundation
import SwiftData

enum TaskSource: String, Codable {
    case notification
    case manual
}

enum TaskStatus: String, Codable {
    case pending
    case completed
    case dropped
    case deferred
    case aging
    case expired
    case archived
}

enum TaskCategory: String, Codable, CaseIterable {
    case work, social, system, finance, health, shopping, other

    var displayName: String {
        switch self {
        case .work: "工作"
        case .social: "社交"
        case .system: "系统"
        case .finance: "财务"
        case .health: "健康"
        case .shopping: "购物"
        case .other: "其他"
        }
    }
}

struct SubNotification: Codable, Identifiable {
    var id: UUID
    let title: String
    let body: String
    let appName: String?
    let sender: String?
    let arrivedAt: Date

    init(title: String, body: String, appName: String? = nil, sender: String? = nil) {
        self.id = UUID()
        self.title = title
        self.body = body
        self.appName = appName
        self.sender = sender
        self.arrivedAt = Date()
    }
}

@Model
final class TaskItem {
    var id: UUID
    var title: String
    var body: String
    var source: TaskSource
    var status: TaskStatus

    var appName: String?
    var appBundleId: String?
    var sender: String?

    var category: TaskCategory?
    var urgency: Int
    var importance: Int
    var priority: Double

    var createdAt: Date
    var processedAt: Date?
    var deferCount: Int
    var lastDeferredAt: Date?

    var llmReason: String?
    var suggestedAction: String?
    var notificationUUID: String?

    var groupId: String?
    var subNotificationsData: Data?
    var notificationCount: Int
    var isUrgent: Bool

    init(
        title: String,
        body: String = "",
        source: TaskSource,
        appName: String? = nil,
        appBundleId: String? = nil,
        sender: String? = nil,
        urgency: Int = 5,
        importance: Int = 5
    ) {
        self.id = UUID()
        self.title = title
        self.body = body
        self.source = source
        self.status = .pending
        self.appName = appName
        self.appBundleId = appBundleId
        self.sender = sender
        self.urgency = urgency
        self.importance = importance
        self.priority = 5.0
        self.createdAt = Date()
        self.deferCount = 0
        self.notificationCount = 1
        self.isUrgent = false
    }

    var ageSinceCreation: TimeInterval {
        Date().timeIntervalSince(createdAt)
    }

    var isOverdue: Bool {
        status == .aging || status == .expired
    }

    var isAggregated: Bool { notificationCount > 1 }

    var subNotifications: [SubNotification] {
        get {
            guard let data = subNotificationsData else { return [] }
            return (try? JSONDecoder().decode([SubNotification].self, from: data)) ?? []
        }
        set {
            subNotificationsData = try? JSONEncoder().encode(newValue)
        }
    }

    func mergeNotification(title: String, body: String, sender: String? = nil) {
        var subs = subNotifications
        subs.append(SubNotification(title: title, body: body, appName: appName, sender: sender))
        subNotifications = subs
        notificationCount = 1 + subs.count
    }

    var snapshot: TaskSnapshot {
        TaskSnapshot(
            title: title,
            body: body,
            appName: appName,
            sender: sender,
            createdAt: createdAt,
            urgency: urgency,
            importance: importance
        )
    }
}
