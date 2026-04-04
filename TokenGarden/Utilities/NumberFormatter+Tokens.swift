import Foundation

enum TokenFormatter {
    static func format(_ value: Int) -> String {
        if value < 1000 {
            return "\(value)"
        } else if value < 1_000_000 {
            let k = Double(value) / 1000.0
            if k.truncatingRemainder(dividingBy: 1) == 0 {
                return "\(Int(k))K"
            }
            let formatted = String(format: "%.1fK", k)
            return formatted.replacingOccurrences(of: ".0K", with: "K")
        } else {
            let m = Double(value) / 1_000_000.0
            if m.truncatingRemainder(dividingBy: 1) == 0 {
                return "\(Int(m))M"
            }
            let formatted = String(format: "%.1fM", m)
            return formatted.replacingOccurrences(of: ".0M", with: "M")
        }
    }

    static func formatCredits(_ value: Double) -> String {
        if value >= 1000 {
            let formatted = String(format: value.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.1f", value)
            return "\(formatted) cr"
        }
        if value >= 10 {
            return "\(String(format: "%.1f", value).replacingOccurrences(of: ".0", with: "")) cr"
        }
        return "\(String(format: "%.2f", value).replacingOccurrences(of: ".00", with: "")) cr"
    }
}
