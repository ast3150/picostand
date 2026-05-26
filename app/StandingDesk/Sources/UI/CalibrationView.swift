import SwiftUI

struct CalibrationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SerialReader.self) private var reader
    @Environment(AppSettings.self) private var settings

    @State private var capturedSit: Int?
    @State private var capturedStand: Int?

    private let plausibleRange = 400...1400  // mm — wider than sit/stand to allow odd desks

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            liveReading
                .padding(.vertical, 28)

            Divider()

            capturePanel
                .padding(20)

            Divider()

            footer
                .padding(16)
        }
        .frame(width: 460)
        .onAppear { setCal(on: true) }
        .onDisappear { setCal(on: false) }
    }

    // MARK: - Sections

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "ruler")
                .font(.title2)
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 2) {
                Text("Calibrate desk").font(.headline)
                Text("Capture the distance at sit and stand height. The Pico will use these to detect transitions.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
    }

    private var liveReading: some View {
        VStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(reader.lastDistanceMm.map { String(format: "%.1f", Double($0) / 10.0) } ?? "—")
                    .font(.system(size: 56, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(readingTint)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: reader.lastDistanceMm)
                Text("cm")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 6) {
                if !readingValid && reader.lastDistanceMm != nil {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
                Text(readingHint)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var readingValid: Bool {
        guard let d = reader.lastDistanceMm else { return false }
        return plausibleRange.contains(d)
    }

    private var readingTint: Color {
        guard let d = reader.lastDistanceMm else { return .primary }
        return plausibleRange.contains(d) ? .primary : .orange
    }

    private var readingHint: String {
        guard let d = reader.lastDistanceMm else { return connectionHint }
        if !plausibleRange.contains(d) {
            return "Sensor blocked or out of range — clear the area under the desk."
        }
        return connectionHint
    }

    private var capturePanel: some View {
        HStack(spacing: 16) {
            captureBox(
                title: "Sitting",
                icon: "chair",
                tint: .orange,
                value: capturedSit ?? settings.sitThresholdMm,
                isCaptured: capturedSit != nil,
                action: { if let d = validReading() { capturedSit = d } }
            )
            captureBox(
                title: "Standing",
                icon: "figure.stand",
                tint: .green,
                value: capturedStand ?? settings.standThresholdMm,
                isCaptured: capturedStand != nil,
                action: { if let d = validReading() { capturedStand = d } }
            )
        }
    }

    private func captureBox(title: String, icon: String, tint: Color, value: Int, isCaptured: Bool, action: @escaping () -> Void) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon).foregroundStyle(tint)
                Text(title).font(.headline)
            }
            Text(Format.cm(value))
                .font(.title.monospacedDigit().weight(.semibold))
                .foregroundStyle(isCaptured ? .primary : .secondary)
            Button(action: action) {
                Label(isCaptured ? "Recapture" : "Capture", systemImage: "scope")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(tint)
            .disabled(!readingValid)
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(.quaternary.opacity(0.5)))
    }

    private var footer: some View {
        HStack {
            if let warning = validationWarning {
                Label(warning, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            Spacer()
            Button("Cancel") { dismiss() }
                .keyboardShortcut(.cancelAction)
            Button("Apply") { apply() }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(!canApply)
        }
    }

    // MARK: - Logic

    private var connectionHint: String {
        switch reader.connection {
        case .connected: "Lower or raise the desk, then capture."
        case .connecting: "Connecting to desk…"
        case .disconnected: "Desk not connected."
        }
    }

    private var validationWarning: String? {
        if capturedSit == nil && capturedStand == nil { return nil }
        let sit = capturedSit ?? settings.sitThresholdMm
        let stand = capturedStand ?? settings.standThresholdMm
        if stand <= sit { return "Standing must be larger than sitting." }
        if stand - sit < 100 { return "Sit/stand difference is small — readings may flap." }
        return nil
    }

    private var canApply: Bool {
        guard capturedSit != nil || capturedStand != nil else { return false }
        let sit = capturedSit ?? settings.sitThresholdMm
        let stand = capturedStand ?? settings.standThresholdMm
        return stand > sit
    }

    private func apply() {
        let sit = capturedSit ?? settings.sitThresholdMm
        let stand = capturedStand ?? settings.standThresholdMm
        settings.sitThresholdMm = sit
        settings.standThresholdMm = stand
        reader.send(["cmd": "cfg", "sit": sit, "stand": stand])
        dismiss()
    }

    private func setCal(on: Bool) {
        reader.send(["cmd": "cal", "on": on])
    }

    private func validReading() -> Int? {
        guard let d = reader.lastDistanceMm, plausibleRange.contains(d) else { return nil }
        return d
    }
}
