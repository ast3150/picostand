import SwiftUI
import SwiftData

@main
struct PicostandApp: App {
    @State private var store = SessionStore()
    @State private var reader = SerialReader()
    @State private var settings = AppSettings()
    @State private var notifier = NotificationScheduler()
    @State private var idleWatcher: IdleWatcher?
    @State private var didWire = false

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environment(store)
                .environment(reader)
                .environment(settings)
        } label: {
            Image(systemName: menuBarSymbol)
                .task(id: "wireApp") { await wireApp() }
        }
        .menuBarExtraStyle(.window)

        Window("Picostand", id: "main") {
            MainWindow()
                .environment(store)
                .environment(reader)
                .environment(settings)
                .modelContainer(store.container)
        }
        .defaultSize(width: 720, height: 600)
        .windowToolbarStyle(.unified)

        Settings {
            SettingsView()
                .environment(store)
                .environment(reader)
                .environment(settings)
        }
    }

    private var menuBarSymbol: String {
        switch store.currentState {
        case .standing: "figure.stand"
        case .sitting: "chair"
        case .unknown: "questionmark.circle"
        }
    }

    @MainActor
    private func wireApp() async {
        guard !didWire else { return }
        didWire = true
        reader.onEvent = { event in
            store.handle(event)
        }
        reader.onSensorBlockedDidChange = { blocked, lastValidAt in
            if blocked {
                store.markSensorBlocked(at: lastValidAt ?? .now)
            }
        }
        reader.start()
        let watcher = IdleWatcher { time in store.markSensorBlocked(at: time) }
        watcher.start()
        idleWatcher = watcher
        await notifier.requestAuthorization()
        notifier.bind(store: store, settings: settings, reader: reader)
    }
}
