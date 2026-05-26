import SwiftUI
import SwiftData
import Charts

struct MainWindow: View {
    @Environment(SessionStore.self) private var store
    @Environment(SerialReader.self) private var reader
    @Environment(AppSettings.self) private var settings
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                heroCard
                Grid(horizontalSpacing: 18, verticalSpacing: 18) {
                    GridRow {
                        streakCard
                        weeklyCard
                    }
                }
                todayCard
            }
            .padding(22)
        }
        .frame(minWidth: 640, minHeight: 560)
        .background(.windowBackground)
        .navigationTitle("Standing Desk")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    openSettings()
                } label: {
                    Image(systemName: "gearshape")
                }
            }
        }
    }

    // MARK: - Hero

    private var heroCard: some View {
        let _ = store.revision
        let totals = store.totals()
        let goal = settings.dailyStandGoalSeconds
        let progress = goal > 0 ? min(1, totals.stand / goal) : 0

        return HStack(alignment: .center, spacing: 28) {
            ZStack {
                Circle().stroke(.quaternary, lineWidth: 14)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(.green.gradient, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.4), value: progress)
                VStack(spacing: 0) {
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 36, weight: .bold, design: .rounded).monospacedDigit())
                    Text("of \(Int(settings.dailyStandGoalMinutes / 60))h goal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 150, height: 150)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Circle().fill(stateTint).frame(width: 8, height: 8)
                    Text(stateText)
                        .font(.title.bold())
                }
                Text(subline)
                    .foregroundStyle(.secondary)
                HStack(spacing: 20) {
                    bigStat(value: Format.duration(totals.stand), label: "Standing", tint: .green, icon: "figure.stand")
                    bigStat(value: Format.duration(totals.sit), label: "Sitting", tint: .orange, icon: "chair")
                }
                .padding(.top, 6)
            }
            Spacer()
        }
        .padding(24)
        .background(card)
    }

    private func bigStat(value: String, label: String, tint: Color, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 0) {
                Text(value).font(.title3.bold().monospacedDigit())
                Text(label).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Streak

    private var streakCard: some View {
        let _ = store.revision
        let goal = settings.dailyStandGoalSeconds
        let streak = store.currentStreak(goalSecs: goal)
        return VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Streak", systemImage: "flame.fill", tint: .red)
            Spacer(minLength: 0)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(streak)")
                    .font(.system(size: 56, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(streak > 0 ? AnyShapeStyle(Color.red.gradient) : AnyShapeStyle(Color.secondary))
                Text(streak == 1 ? "day" : "days")
                    .foregroundStyle(.secondary)
            }
            Text(streak > 0 ? "Keep it going!" : "Stand for \(settings.dailyStandGoalMinutes / 60)h today to start.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(20)
        .background(card)
    }

    // MARK: - Weekly

    private var weeklyCard: some View {
        let _ = store.revision
        let days = store.dailyStandTotals(days: 7)
        let goalMin = Double(settings.dailyStandGoalMinutes)
        return VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Last 7 days", systemImage: "calendar", tint: .blue)
            Chart {
                ForEach(days.indices, id: \.self) { i in
                    let d = days[i]
                    BarMark(
                        x: .value("day", d.day, unit: .day),
                        y: .value("min", d.stand / 60)
                    )
                    .foregroundStyle(d.stand / 60 >= goalMin ? Color.green : Color.green.opacity(0.5))
                    .cornerRadius(4)
                }
                RuleMark(y: .value("goal", goalMin))
                    .foregroundStyle(.secondary)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("goal")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { val in
                    AxisValueLabel(format: .dateTime.weekday(.narrow), centered: true)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { val in
                    AxisValueLabel {
                        if let m = val.as(Double.self) {
                            Text("\(Int(m))m")
                        }
                    }
                    AxisGridLine()
                }
            }
            .frame(height: 140)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
        .background(card)
    }

    // MARK: - Today timeline

    private var todayCard: some View {
        let _ = store.revision
        let sessions = store.sessions()
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: .now)
        let endOfDay = cal.date(byAdding: .day, value: 1, to: startOfDay)!
        return VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Today", systemImage: "clock", tint: .purple)
            if sessions.isEmpty {
                Text("No activity yet.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 30)
            } else {
                Chart(sessions, id: \.persistentModelID) { s in
                    BarMark(
                        xStart: .value("start", max(s.startedAt, startOfDay)),
                        xEnd: .value("end", min(s.endedAt ?? .now, endOfDay)),
                        y: .value("row", "")
                    )
                    .foregroundStyle(s.deskState.tint)
                    .cornerRadius(3)
                }
                .chartXScale(domain: startOfDay...endOfDay)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .hour, count: 3)) { _ in
                        AxisValueLabel(format: .dateTime.hour())
                        AxisGridLine()
                    }
                }
                .chartYAxis(.hidden)
                .frame(height: 44)

                Divider().padding(.vertical, 4)

                ForEach(Array(sessions.reversed().prefix(8)), id: \.persistentModelID) { s in
                    sessionRow(s)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(card)
    }

    private func sessionRow(_ s: Session) -> some View {
        HStack(spacing: 10) {
            Image(systemName: s.deskState.icon)
                .foregroundStyle(s.deskState.tint)
                .frame(width: 16)
            Text(s.deskState.rawValue.capitalized)
            if s.isOpen {
                Text("• ongoing").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(s.startedAt, style: .time).foregroundStyle(.secondary).monospacedDigit()
            Text("·").foregroundStyle(.tertiary)
            Text(Format.duration(s.duration)).monospacedDigit().frame(width: 60, alignment: .trailing)
        }
        .font(.callout)
        .padding(.vertical, 2)
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String, systemImage: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage).foregroundStyle(tint)
            Text(title).font(.headline)
        }
    }

    private var card: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(.regularMaterial)
    }

    private var stateTint: Color {
        reader.sensorBlocked ? .orange : store.currentState.tint
    }

    private var stateText: String {
        reader.sensorBlocked ? "Sensor blocked" : store.currentState.label
    }

    private var subline: String {
        if reader.sensorBlocked {
            return "Reading \(Format.cm(reader.lastDistanceMm ?? 0)) — clear the area under the desk."
        }
        switch reader.connection {
        case .disconnected: return "Desk not connected"
        case .connecting:   return "Connecting…"
        case .connected:
            if let open = store.openSession() {
                return "for \(Format.duration(open.duration)) — since \(open.startedAt.formatted(date: .omitted, time: .shortened))"
            }
            return "Connected · waiting for sensor reading"
        }
    }
}

extension Session: Identifiable {}
