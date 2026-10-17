// Sources/MeetingMeter/Services/NotificationService.swift
import UserNotifications

public final class NotificationService {
    public init() {}

    public func requestAuthorizationIfNeeded() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    public func postMeetingEnded(totalCost: Double, currency: String, durationSeconds: Double) {
        let content = UNMutableNotificationContent()
        content.title = "Réunion terminée"
        let minutes = Int(durationSeconds / 60)
        let cost = String(format: "%.2f %@", totalCost, currency)
        content.body = "\(minutes) min — \(cost)"
        content.sound = .default
        let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }
}
