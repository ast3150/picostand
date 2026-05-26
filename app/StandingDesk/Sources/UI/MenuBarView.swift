import SwiftUI
import SwiftData

struct MenuBarView: View {
    @Environment(SessionStore.self) private var store
    @Environment(SerialReader.self) private var reader
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Divider()
            stats
            Divider()
            HStack {
                Button("Open Window") { openWindow(id: "main") }
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
            }
        }
        .padding(12)
        .frame(width: 260)
    }

    private var header: some View {
        HStack {
            Image(systemName: stateIcon)
                .font(.title2)
            VStack(alignment: .leading) {
                Text(stateText).font(.headline)
                Text(connectionText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var stats: some View {
        let totals = store.totals()
        let total = totals.sit + totals.stand
        let pct = total > 0 ? Int((totals.stand / total) * 100) : 0
        return VStack(alignment: .leading, spacing: 4) {
            Text("Today").font(.subheadline).foregroundStyle(.secondary)
            Text("\(pct)% standing").font(.title3.monospacedDigit())
            HStack {
                Label(format(totals.stand), systemImage: "figure.stand")
                Spacer()
                Label(format(totals.sit), systemImage: "chair")
            }
            .font(.caption.monospacedDigit())
        }
    }

    private var stateIcon: String {
        switch store.currentState {
        case .standing: "figure.stand"
        case .sitting: "chair"
        case .unknown: "questionmark.circle"
        }
    }

    private var stateText: String {
        switch store.currentState {
        case .standing: "Standing"
        case .sitting: "Sitting"
        case .unknown: "Unknown"
        }
    }

    private var connectionText: String {
        switch reader.connection {
        case .disconnected: "Not connected"
        case .connecting: "Connecting…"
        case .connected: "Connected"
        }
    }

    private func format(_ t: TimeInterval) -> String {
        let m = Int(t) / 60
        if m < 60 { return "\(m) min" }
        return String(format: "%dh %02dm", m / 60, m % 60)
    }
}
