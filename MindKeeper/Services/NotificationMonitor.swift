import Foundation
import SQLite3

actor NotificationMonitor {
    private var lastDeliveredDate: Double = 0
    private var knownUUIDs: Set<String> = []
    private var dbPath: String?

    var isDatabaseAccessible: Bool {
        dbPath != nil
    }

    func start(onNew: @escaping @Sendable ([NotificationRecord]) -> Void) {
        guard let path = resolveDBPath() else {
            print("[NotificationMonitor] ⚠️ 未找到通知数据库或无权限访问")
            return
        }
        dbPath = path
        print("[NotificationMonitor] 数据库路径: \(path)")

        guard canOpenDB(path: path) else {
            print("[NotificationMonitor] ⚠️ 数据库存在但无法打开 - 需要「完全磁盘访问」权限")
            dbPath = nil
            return
        }

        loadLastTimestamp()
        print("[NotificationMonitor] 开始监听，起始时间戳: \(lastDeliveredDate)")

        let interval: TimeInterval = UserDefaults.standard.double(forKey: "pollInterval")
        let pollSeconds = interval > 0 ? interval : 4.0

        Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let records = await self.poll()
                if !records.isEmpty {
                    print("[NotificationMonitor] 获取到 \(records.count) 条新通知")
                    onNew(records)
                }
                try? await Task.sleep(for: .seconds(pollSeconds))
            }
        }
    }

    func checkAccess() -> Bool {
        guard let path = resolveDBPath() else { return false }
        return canOpenDB(path: path)
    }

    private func canOpenDB(path: String) -> Bool {
        var db: OpaquePointer?
        let result = sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY, nil)
        defer { sqlite3_close(db) }
        return result == SQLITE_OK
    }

    private func poll() -> [NotificationRecord] {
        guard let path = dbPath else { return [] }
        var db: OpaquePointer?
        guard sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            return []
        }
        defer { sqlite3_close(db) }

        let query = """
            SELECT r.data, r.delivered_date, r.uuid
            FROM record r
            WHERE r.delivered_date > ?
            ORDER BY r.delivered_date ASC
            LIMIT 50
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
            return []
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_double(stmt, 1, lastDeliveredDate)

        var records: [NotificationRecord] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let dataBlob = sqlite3_column_blob(stmt, 0) else { continue }
            let dataLen = sqlite3_column_bytes(stmt, 0)
            let data = Data(bytes: dataBlob, count: Int(dataLen))
            let deliveredDate = sqlite3_column_double(stmt, 1)

            let uuidCol = sqlite3_column_text(stmt, 2)
            let uuid = uuidCol.map { String(cString: $0) } ?? UUID().uuidString

            guard !knownUUIDs.contains(uuid) else { continue }

            if var record = PlistParser.parseNotificationData(data) {
                record = NotificationRecord(
                    id: uuid,
                    title: record.title,
                    subtitle: record.subtitle,
                    body: record.body,
                    appName: record.appName,
                    bundleId: record.bundleId,
                    deliveredDate: Date(timeIntervalSinceReferenceDate: deliveredDate),
                    presented: record.presented
                )
                records.append(record)
                knownUUIDs.insert(uuid)
                lastDeliveredDate = max(lastDeliveredDate, deliveredDate)
            }
        }

        saveLastTimestamp()
        return records
    }

    private func resolveDBPath() -> String? {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        let groupPath = "\(homeDir)/Library/Group Containers/group.com.apple.usernoted/db2/db"
        if FileManager.default.fileExists(atPath: groupPath) {
            return groupPath
        }

        let darwinDir = getDarwinUserDir()
        if let dir = darwinDir {
            let legacyPath = "\(dir)com.apple.notificationcenter/db2/db"
            if FileManager.default.fileExists(atPath: legacyPath) {
                return legacyPath
            }
        }

        return nil
    }

    private func getDarwinUserDir() -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/getconf")
        process.arguments = ["DARWIN_USER_DIR"]
        let pipe = Pipe()
        process.standardOutput = pipe
        try? process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var timestampKey: String { "NotificationMonitor.lastDeliveredDate" }

    private func loadLastTimestamp() {
        lastDeliveredDate = UserDefaults.standard.double(forKey: timestampKey)
        if lastDeliveredDate == 0 {
            lastDeliveredDate = Date().timeIntervalSinceReferenceDate - 3600
        }
    }

    private func saveLastTimestamp() {
        UserDefaults.standard.set(lastDeliveredDate, forKey: timestampKey)
    }
}
