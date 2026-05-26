import Foundation

enum Format {
    /// Display millimetres as "63.3 cm" (one decimal).
    static func cm(_ mm: Int) -> String {
        String(format: "%.1f cm", Double(mm) / 10.0)
    }
}
