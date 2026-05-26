import SwiftUI
import SwiftData

@main
struct StandingDeskApp: App {
    @State private var store = SessionStore()
    @State private var reader = SerialReader()

    init() {}

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environment(store)
                .environment(reader)
        } label: {
            Image(systemName: menuBarSymbol)
        }
        .menuBarExtraStyle(.window)

        Window("Standing Desk", id: "main") {
            MainWindow()
                .environment(store)
                .environment(reader)
                .modelContainer(store.container)
                .task {
                    await wireReader()
                }
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
    private func wireReader() async {
        reader.onEvent = { event in
            store.handle(event)
        }
        reader.start()
    }
}
