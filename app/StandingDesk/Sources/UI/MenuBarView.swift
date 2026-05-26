import SwiftUI

struct MenuBarView: View {
    @Environment(SessionStore.self) private var store
    @Environment(SerialReader.self) private var reader
    @Environment(AppSettings.self) private var settings
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            hero
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 14)

            ringSection
                .padding(.horizontal, 16)
                .padding(.bottom, 14)

            Divider()

            HStack(spacing: 8) {
                Button {
                    openWindow(id: "main")
                } label: {
                    Label("Stats", systemImage: "chart.bar.fill")
                }
                Button {
                    openSettings()
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
                Spacer()
                Menu {
                    Button("Quit Standing Desk") { NSApplication.shared.terminate(nil) }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .frame(width: 28)
            }
            .buttonStyle(.borderless)
            .padding(12)
        }
        .frame(width: 300)
        .background(.regularMaterial)
    }

    private var hero: some View {
        let _ = store.revision
        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(stateTint.opacity(0.18))
                    .frame(width: 54, height: 54)
                Image(systemName: stateIcon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(stateTint)
                    .symbolEffect(.bounce, value: store.currentState)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(stateText)
                    .font(.title2.bold())
                Text(subline)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var ringSection: some View {
        let _ = store.revision
        let totals = store.totals()
        let goal = settings.dailyStandGoalSeconds
        let progress = goal > 0 ? min(1, totals.stand / goal) : 0
        return HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(.tertiary, lineWidth: 8)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(.green.gradient, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.4), value: progress)
                VStack(spacing: 0) {
                    Text("\(Int(progress * 100))%")
                        .font(.title3.bold().monospacedDigit())
                    Text("of goal")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 72, height: 72)

            VStack(alignment: .leading, spacing: 8) {
                statRow(icon: "figure.stand", label: "Standing", value: Format.duration(totals.stand), tint: .green)
                statRow(icon: "chair", label: "Sitting", value: Format.duration(totals.sit), tint: .orange)
                statRow(icon: "flame.fill", label: "Streak", value: "\(store.currentStreak(goalSecs: goal))d", tint: .red)
            }
            Spacer()
        }
    }

    private func statRow(icon: String, label: String, value: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).foregroundStyle(tint).frame(width: 14)
            Text(label).foregroundStyle(.secondary).font(.caption)
            Spacer()
            Text(value).font(.caption.monospacedDigit().weight(.semibold))
        }
    }

    private var subline: String {
        if reader.sensorBlocked { return "Sensor blocked or misaimed" }
        switch reader.connection {
        case .disconnected: return "Desk not connected"
        case .connecting:   return "Connecting…"
        case .connected:
            if let open = store.openSession() {
                return "for \(Format.duration(open.duration)) · today"
            }
            return "Waiting for sensor reading…"
        }
    }

    private var stateIcon: String {
        reader.sensorBlocked ? "exclamationmark.triangle.fill" : store.currentState.icon
    }

    private var stateText: String {
        reader.sensorBlocked ? "Sensor blocked" : store.currentState.label
    }

    private var stateTint: Color {
        reader.sensorBlocked ? .orange : store.currentState.tint
    }
}
