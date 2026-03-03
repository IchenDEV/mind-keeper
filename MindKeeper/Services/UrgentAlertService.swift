import AppKit
import UserNotifications

@MainActor
final class UrgentAlertService {
    private var lastAlertTime: Date = .distantPast
    private let cooldown: TimeInterval = 30

    var soundEnabled: Bool {
        UserDefaults.standard.bool(forKey: "urgentSoundEnabled")
    }

    func alertIfNeeded(for task: TaskItem) {
        guard task.isUrgent else { return }
        guard Date().timeIntervalSince(lastAlertTime) > cooldown else { return }
        lastAlertTime = Date()

        if soundEnabled {
            playUrgentSound()
        }

        sendLocalNotification(for: task)
    }

    private func playUrgentSound() {
        if let sound = NSSound(named: .init("Ping")) {
            sound.volume = 0.8
            sound.play()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                if let s2 = NSSound(named: .init("Ping")) {
                    s2.volume = 0.6
                    s2.play()
                }
            }
        } else {
            NSSound.beep()
        }
    }

    private func sendLocalNotification(for task: TaskItem) {
        let content = UNMutableNotificationContent()
        content.title = "紧急任务"
        content.body = task.title
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        let request = UNNotificationRequest(
            identifier: "urgent-\(task.id.uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
