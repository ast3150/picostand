import Foundation
import SwiftData

@MainActor
@Observable
final class SessionStore {
    let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    private(set) var currentState: DeskState = .unknown
    private(set) var lastSeq: Int = 0

    init() {
        do {
            container = try ModelContainer(for: Session.self)
        } catch {
            fatalError("ModelContainer: \(error)")
        }
        // Initialize currentState from any open session
        if let open = openSession() {
            currentState = open.deskState
        }
    }

    func handle(_ event: PicoEvent) {
        switch event {
        case let .transition(state, _, seq):
            applyTransition(to: state, seq: seq)
        case let .heartbeat(state, _, seq):
            // First heartbeat after a fresh boot: opens initial session if none
            if currentState == .unknown, state != .unknown {
                applyTransition(to: state, seq: seq)
            }
        default:
            break
        }
    }

    private func applyTransition(to state: DeskState, seq: Int) {
        guard state != .unknown else { return }
        // Idempotency: ignore replayed seq we've already applied
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
        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate {
                $0.startedAt < end &&
                ($0.endedAt == nil || $0.endedAt! >= start)
            },
            sortBy: [SortDescriptor(\.startedAt)]
        )
        return (try? context.fetch(descriptor)) ?? []
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
}
