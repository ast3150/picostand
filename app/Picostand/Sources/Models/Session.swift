import Foundation
import SwiftData

@Model
final class Session {
    var startedAt: Date
    var endedAt: Date?
    var state: String

    init(startedAt: Date, endedAt: Date? = nil, state: DeskState) {
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.state = state.rawValue
    }

    var deskState: DeskState { DeskState(rawValue: state) ?? .unknown }
    var isOpen: Bool { endedAt == nil }
    var duration: TimeInterval { (endedAt ?? .now).timeIntervalSince(startedAt) }
}
