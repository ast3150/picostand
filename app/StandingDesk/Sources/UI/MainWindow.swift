import SwiftUI
import SwiftData
import Charts

struct MainWindow: View {
    @Environment(SessionStore.self) private var store
    @Environment(SerialReader.self) private var reader

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            Divider()
            todayChart
            sessionList
        }
        .padding(20)
        .frame(minWidth: 520, minHeight: 420)
    }

    private var header: some View {
        let totals = store.totals()
        let total = totals.sit + totals.stand
        let pct = total > 0 ? Int((totals.stand / total) * 100) : 0
        return HStack(alignment: .top) {
            VStack(alignment: .leading) {
                Text("Today").font(.title).bold()
                Text("\(pct)% standing — \(format(totals.stand)) of \(format(total))")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text(store.currentState == .standing ? "Standing" : store.currentState == .sitting ? "Sitting" : "—")
                    .font(.headline)
                Text(connectionText).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var todayChart: some View {
        let sessions = store.sessions()
        return Chart(sessions) { s in
            BarMark(
                xStart: .value("start", s.startedAt),
                xEnd: .value("end", s.endedAt ?? .now),
                y: .value("state", s.state)
            )
            .foregroundStyle(s.deskState == .standing ? Color.green : Color.orange)
        }
        .frame(height: 80)
    }

    private var sessionList: some View {
        let sessions = store.sessions().reversed()
        return List(Array(sessions), id: \.persistentModelID) { s in
            HStack {
                Image(systemName: s.deskState == .standing ? "figure.stand" : "chair")
                Text(s.deskState.rawValue.capitalized)
                Spacer()
                Text(format(s.duration)).monospacedDigit()
                    .foregroundStyle(.secondary)
                Text(s.startedAt, style: .time)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var connectionText: String {
        switch reader.connection {
        case .disconnected: "Disconnected"
        case .connecting: "Connecting…"
        case .connected(let path): "Connected (\((path as NSString).lastPathComponent))"
        }
    }

    private func format(_ t: TimeInterval) -> String {
        let m = Int(t) / 60
        if m < 60 { return "\(m)m" }
        return String(format: "%dh %02dm", m / 60, m % 60)
    }
}

extension Session: Identifiable {}
