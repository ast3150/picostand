import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettings()
                .tabItem { Label("General", systemImage: "gearshape") }
            NotificationsSettings()
                .tabItem { Label("Notifications", systemImage: "bell.badge") }
            DeskSettings()
                .tabItem { Label("Desk", systemImage: "ruler") }
        }
        .frame(width: 480, height: 360)
    }
}

private struct GeneralSettings: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section {
                Stepper(value: $settings.dailyStandGoalMinutes, in: 30...360, step: 15) {
                    LabeledContent("Daily standing goal") {
                        Text(format(minutes: settings.dailyStandGoalMinutes))
                            .monospacedDigit()
                    }
                }
            } footer: {
                Text("How long you want to stand each day.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func format(minutes: Int) -> String {
        if minutes < 60 { return "\(minutes) min" }
        let h = minutes / 60
        let m = minutes % 60
        return m == 0 ? "\(h) h" : "\(h) h \(m) min"
    }
}

private struct NotificationsSettings: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section {
                Toggle("Remind me to stand", isOn: $settings.notificationsEnabled)
                Stepper(value: $settings.remindAfterSittingMinutes, in: 15...120, step: 5) {
                    LabeledContent("After sitting for") {
                        Text("\(settings.remindAfterSittingMinutes) min")
                            .monospacedDigit()
                    }
                }
                .disabled(!settings.notificationsEnabled)
            } footer: {
                Text("Reminders are paused when the desk is not connected.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

private struct DeskSettings: View {
    @Environment(AppSettings.self) private var settings
    @Environment(SessionStore.self) private var store
    @Environment(SerialReader.self) private var reader
    @State private var showingCalibration = false

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section("Connection") {
                LabeledContent("Status", value: connectionText)
                if let d = reader.lastDistanceMm {
                    LabeledContent("Sensor reading") {
                        Text(Format.cm(d)).monospacedDigit()
                    }
                }
            }
            Section {
                LabeledContent("Sitting") { Text(Format.cm(settings.sitThresholdMm)).monospacedDigit() }
                LabeledContent("Standing") { Text(Format.cm(settings.standThresholdMm)).monospacedDigit() }
                Button {
                    showingCalibration = true
                } label: {
                    Label("Calibrate…", systemImage: "scope")
                }
                .disabled(!reader.isConnected)
            } header: {
                Text("Thresholds")
            } footer: {
                Text("Distance from desk underside to floor. Calibration captures live sensor readings at each height.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Maintenance") {
                Button("Reset last hour", role: .destructive) {
                    store.resetLastHour()
                }
                Button("Reset today", role: .destructive) {
                    store.resetToday()
                }
                Button("Reset all data", role: .destructive) {
                    store.resetAll()
                }
            }
        }
        .formStyle(.grouped)
        .sheet(isPresented: $showingCalibration) {
            CalibrationView()
                .environment(settings)
                .environment(reader)
        }
    }

    private var connectionText: String {
        switch reader.connection {
        case .disconnected: "Not connected"
        case .connecting(let path): "Connecting to \((path as NSString).lastPathComponent)…"
        case .connected(let path): "Connected — \((path as NSString).lastPathComponent)"
        }
    }

}
