import AppKit
import Foundation

/// Truncates the open session when the Mac sleeps or the screen locks, so time spent
/// away from the desk isn't counted. After wake/unlock the next sensor heartbeat
/// reopens a session via SessionStore's `currentState == .unknown` path.
@MainActor
final class IdleWatcher {
    private var observers: [NSObjectProtocol] = []
    private let onIdle: (Date) -> Void

    init(onIdle: @escaping (Date) -> Void) {
        self.onIdle = onIdle
    }

    func start() {
        let workspace = NSWorkspace.shared.notificationCenter
        observers.append(workspace.addObserver(
            forName: NSWorkspace.willSleepNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.onIdle(.now) }
        })

        let distributed = DistributedNotificationCenter.default()
        observers.append(distributed.addObserver(
            forName: .init("com.apple.screenIsLocked"), object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.onIdle(.now) }
        })
    }

    deinit {
        let workspace = NSWorkspace.shared.notificationCenter
        let distributed = DistributedNotificationCenter.default()
        for o in observers {
            workspace.removeObserver(o)
            distributed.removeObserver(o)
        }
    }
}
