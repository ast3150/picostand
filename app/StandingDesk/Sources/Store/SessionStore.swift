import Foundation
import SwiftData

@MainActor
@Observable
final class SessionStore {
    let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    private(set) var currentState: DeskState = .unknown
    private(set) var lastSeq: Int = 0
    // Bumped on insert/edit so views recompute. Also tickled by a 30s timer.
    private(set) var revision: Int = 0
    private var ticker: Timer?

    init() {
        do {
            container = try ModelContainer(for: Session.self)
        } catch {
            fatalError("ModelContainer: \(error)")
        }
        if let open = openSession() {
            currentState = open.deskState
        }
        startTicker()
    }

    private func startTicker() {
        ticker = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.revision &+= 1 }
        }
    }

    func handle(_ event: PicoEvent) {
        switch event {
        case let .transition(state, _, seq):
            applyTransition(to: state, seq: seq)
        case let .heartbeat(state, _, seq):
            if currentState == .unknown, state != .unknown {
                applyTransition(to: state, seq: seq)
            }
        default:
            break
        }
    }

    /// Truncate any open session at `at` and clear current state. Called when the sensor
    /// becomes unreliable so that time spent blocked is not counted toward any goal.
    func markSensorBlocked(at time: Date) {
        if let open = openSession() {
            open.endedAt = time
            try? context.save()
        }
        currentState = .unknown
        revision &+= 1
    }

    private func applyTransition(to state: DeskState, seq: Int) {
        guard state != .unknown else { return }
        if seq != 0, seq <= lastSeq { return }
        if state == currentState { return }
        let now = Date()
        if let open = openSession() {
            open.endedAt = now
        }
        context.insert(Session(startedAt: now, state: state))
        try? context.save()
        currentState = state
        if seq != 0 { lastSeq = seq }
        revision &+= 1
    }

    func openSession() -> Session? {
        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate { $0.endedAt == nil },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor))?.first
    }

    // MARK: - Stats

    func sessions(on day: Date = .now) -> [Session] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: day)
        let end = cal.date(byAdding: .day, value: 1, to: start)!
        // Fetch all and filter in Swift — SwiftData #Predicate misbehaves with optionals.
        let descriptor = FetchDescriptor<Session>(sortBy: [SortDescriptor(\.startedAt)])
        let all = (try? context.fetch(descriptor)) ?? []
        return all.filter { s in
            guard s.startedAt < end else { return false }
            if let e = s.endedAt { return e >= start }
            return true
        }
    }

    func totals(on day: Date = .now) -> (sit: TimeInterval, stand: TimeInterval) {
        let cal = Calendar.current
        let start = cal.startOfDay(for: day)
        let end = min(cal.date(byAdding: .day, value: 1, to: start)!, .now)
        var sit: TimeInterval = 0
        var stand: TimeInterval = 0
        for s in sessions(on: day) {
            let a = max(s.startedAt, start)
            let b = min(s.endedAt ?? .now, end)
            let d = max(0, b.timeIntervalSince(a))
            switch s.deskState {
            case .sitting: sit += d
            case .standing: stand += d
            case .unknown: break
            }
        }
        return (sit, stand)
    }

    /// Days (most recent first) where standing total met the goal.
    /// A day where total desk time was below the goal is skipped (you couldn't have met
    /// the goal even if you'd stood the whole time) — covers weekends, vacations, and
    /// days the Pico was disconnected.
    func currentStreak(goalSecs: TimeInterval) -> Int {
        let cal = Calendar.current
        var n = 0
        var day = Date()
        for _ in 0..<365 {
            let (sit, stand) = totals(on: day)
            let active = sit + stand
            let isToday = cal.isDateInToday(day)
            if active < goalSecs {
                // Not enough desk time to possibly hit the goal — skip.
            } else if stand >= goalSecs {
                n += 1
            } else if isToday {
                // Today, goal not yet met — don't break, look back.
            } else {
                // Past day with enough time at desk to have hit the goal, but didn't.
                break
            }
            day = cal.date(byAdding: .day, value: -1, to: day) ?? day
        }
        return n
    }

    /// Last N days of standing totals, oldest first.
    func dailyStandTotals(days: Int) -> [(day: Date, stand: TimeInterval, sit: TimeInterval)] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        return (0..<days).reversed().map { offset in
            let d = cal.date(byAdding: .day, value: -offset, to: today)!
            let (sit, stand) = totals(on: d)
            return (d, stand, sit)
        }
    }

    // MARK: - Maintenance

    func resetAll() {
        let descriptor = FetchDescriptor<Session>()
        let all = (try? context.fetch(descriptor)) ?? []
        for s in all { context.delete(s) }
        try? context.save()
        currentState = .unknown
        lastSeq = 0
        revision &+= 1
    }

    /// Delete sessions started on or after `cutoff`. Truncate the tail of any session crossing it.
    func resetSessions(since cutoff: Date) {
        let descriptor = FetchDescriptor<Session>()
        let all = (try? context.fetch(descriptor)) ?? []
        for s in all {
            if s.startedAt >= cutoff {
                context.delete(s)
            } else if s.endedAt == nil || s.endedAt! > cutoff {
                s.endedAt = cutoff
            }
        }
        try? context.save()
        currentState = .unknown
        revision &+= 1
    }

    func resetToday() {
        resetSessions(since: Calendar.current.startOfDay(for: .now))
    }

    func resetLastHour() {
        resetSessions(since: Date().addingTimeInterval(-3600))
    }
}
