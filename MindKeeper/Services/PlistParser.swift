import Foundation

struct PlistParser {
    static func parseNotificationData(_ data: Data) -> NotificationRecord? {
        guard let plist = try? PropertyListSerialization.propertyList(
            from: data, options: [], format: nil
        ) as? [String: Any] else {
            return nil
        }

        let req = plist["req"] as? [String: Any] ?? [:]
        let title = req["titl"] as? String ?? ""
        let subtitle = req["subt"] as? String ?? ""
        let body = req["body"] as? String ?? ""
        let appName = plist["app"] as? String ?? "Unknown"

        let bundleId = plist["bid"] as? String
            ?? plist["appid"] as? String
            ?? ""

        let uuid = plist["uuid"] as? String
            ?? UUID().uuidString

        let dateValue = plist["date"] as? Double ?? 0
        let deliveredDate = Date(timeIntervalSinceReferenceDate: dateValue)

        return NotificationRecord(
            id: uuid,
            title: title,
            subtitle: subtitle,
            body: body,
            appName: appName,
            bundleId: bundleId,
            deliveredDate: deliveredDate,
            presented: true
        )
    }
}
