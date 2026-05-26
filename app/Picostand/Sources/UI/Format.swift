import Foundation
import SwiftUI

enum Format {
    /// Display millimetres as "63.3 cm" (one decimal).
    static func cm(_ mm: Int) -> String {
        String(format: "%.1f cm", Double(mm) / 10.0)
    }

    /// Display a duration as "<1m", "45m", or "1h 05m".
    static func duration(_ t: TimeInterval) -> String {
        let m = Int(t) / 60
        if m < 1  { return "<1m" }
        if m < 60 { return "\(m)m" }
        return String(format: "%dh %02dm", m / 60, m % 60)
    }
}

extension DeskState {
    var icon: String {
        switch self {
        case .standing: "figure.stand"
        case .sitting:  "chair"
        case .unknown:  "questionmark.circle"
        }
    }

    var label: String {
        switch self {
        case .standing: "Standing"
        case .sitting:  "Sitting"
        case .unknown:  "Waiting"
        }
    }

    var tint: Color {
        switch self {
        case .standing: .green
        case .sitting:  .orange
        case .unknown:  .gray
        }
    }
}
