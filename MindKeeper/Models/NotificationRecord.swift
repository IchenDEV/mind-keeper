import Foundation

struct NotificationRecord: Identifiable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let body: String
    let appName: String
    let bundleId: String
    let deliveredDate: Date
    let presented: Bool

    func toTaskItem() -> TaskItem {
        TaskItem(
            title: title.isEmpty ? appName : title,
            body: [subtitle, body].filter { !$0.isEmpty }.joined(separator: "\n"),
            source: .notification,
            appName: appName,
            appBundleId: bundleId
        )
    }
}
