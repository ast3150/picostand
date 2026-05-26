import Foundation
import UserNotifications
import Observation

@MainActor
@Observable
final class NotificationScheduler {
    private weak var store: SessionStore?
    private weak var settings: AppSettings?
    private weak var reader: SerialReader?
    private var ticker: Timer?
    private var lastNotifiedSessionId: PersistentSessionID?
    private(set) var authorized = false

    private struct PersistentSessionID: Equatable {
        let startedAt: Date
    }

    func requestAuthorization() async {
        let center = UNUserNotificationCenter.current()
        do {
            authorized = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            authorized = false
        }
    }

    func bind(store: SessionStore, settings: AppSettings, reader: SerialReader) {
        self.store = store
        self.settings = settings
        self.reader = reader
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    private func tick() {
        guard authorized,
              let store, let settings, let reader,
              settings.notificationsEnabled
        else { return }
        guard reader.isConnected else { return }
        // Sensor must be giving believable readings
        guard !reader.sensorBlocked else { return }
        // Only if currently sitting and the open session has run past the reminder threshold
        guard let open = store.openSession(), open.deskState == .sitting else { return }
        let threshold = TimeInterval(settings.remindAfterSittingMinutes * 60)
        guard open.duration >= threshold else { return }

        let sid = PersistentSessionID(startedAt: open.startedAt)
        if lastNotifiedSessionId == sid { return }
        lastNotifiedSessionId = sid

        let content = UNMutableNotificationContent()
        content.title = "Time to stand"
        let mins = Int(open.duration / 60)
        content.body = "You've been sitting for \(mins) min. Stand up and stretch."
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        let request = UNNotificationRequest(
            identifier: "stand-reminder-\(open.startedAt.timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
