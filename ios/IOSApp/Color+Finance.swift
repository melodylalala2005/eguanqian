import SwiftUI

extension Color {
    init?(hex: String) {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        cleaned = cleaned.replacingOccurrences(of: "#", with: "")

        guard !cleaned.isEmpty else { return nil }
        if cleaned.count == 6 {
            cleaned = "FF" + cleaned
        }

        guard cleaned.count == 8, let value = UInt64(cleaned, radix: 16) else { return nil }

        let alpha = Double((value & 0xFF000000) >> 24) / 255
        let red = Double((value & 0x00FF0000) >> 16) / 255
        let green = Double((value & 0x0000FF00) >> 8) / 255
        let blue = Double(value & 0x000000FF) / 255

        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }

    static func lerp(from start: Color, to end: Color, progress: Double) -> Color {
        let clamped = min(max(progress, 0), 1)
        #if canImport(UIKit)
        let startComponents = UIColor(start).rgba
        let endComponents = UIColor(end).rgba

        let red = startComponents.r + (endComponents.r - startComponents.r) * clamped
        let green = startComponents.g + (endComponents.g - startComponents.g) * clamped
        let blue = startComponents.b + (endComponents.b - startComponents.b) * clamped
        let alpha = startComponents.a + (endComponents.a - startComponents.a) * clamped

        return Color(red: red, green: green, blue: blue, opacity: alpha)
        #else
        return clamped < 0.5 ? start : end
        #endif
    }

    func darker(by amount: Double) -> Color {
        let clamped = min(max(amount, 0), 1)
        return Color.lerp(from: self, to: .black, progress: clamped)
    }
}

enum StatisticsPalette {
    static let pageBackgroundTop = Color(hex: "#F6F8FF") ?? Color(.systemGroupedBackground)
    static let pageBackgroundBottom = Color.white
    static let primary = Color(hex: "#4F46E5") ?? .accentColor
    static let primarySoft = Color(hex: "#EEF2FF") ?? Color(.systemGray6)
    static let outline = Color(hex: "#E0E7FF") ?? Color(.systemGray4)
    static let mutedText = Color(hex: "#6B7280") ?? Color(.secondaryLabel)
    static let cardBackground = Color.white
    static let cardShadow = Color.black.opacity(0.06)
    static let expense = Color(hex: "#FF4D67") ?? .red
    static let income = Color(hex: "#31C48D") ?? .green
    static let divider = Color(hex: "#E5E7EB") ?? Color(.systemGray5)
    static let badgeBackground = Color(hex: "#F1F5F9") ?? Color(.systemGray5)
    static let progressBackground = Color(hex: "#EEF2FF") ?? Color(.systemGray6)
    static let warningStart = Color(hex: "#FB923C") ?? .orange
    static let warningEnd = Color(hex: "#F97316") ?? .orange

    static let expenseCategoryPalette: [Color] = [
        Color(hex: "#6366F1") ?? Color.blue,
        Color(hex: "#F97316") ?? Color.orange,
        Color(hex: "#EC4899") ?? Color.pink,
        Color(hex: "#22C55E") ?? Color.green,
        Color(hex: "#0EA5E9") ?? Color.cyan,
        Color(hex: "#F59E0B") ?? Color.yellow
    ]

    static let incomeCategoryPalette: [Color] = [
        Color(hex: "#0EA5E9") ?? Color.cyan,
        Color(hex: "#22C55E") ?? Color.green,
        Color(hex: "#8B5CF6") ?? Color.purple,
        Color(hex: "#F59E0B") ?? Color.orange,
        Color(hex: "#10B981") ?? Color.green.opacity(0.9),
        Color(hex: "#6366F1") ?? Color.blue
    ]
}

#if canImport(UIKit)
extension UIColor {
    fileprivate var rgba: (r: Double, g: Double, b: Double, a: Double) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return (Double(red), Double(green), Double(blue), Double(alpha))
    }
}
#endif

