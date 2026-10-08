import SwiftUI

enum FinanceColors {
    static let pageBackground = Color(hex: "#F5F6F8") ?? Color(uiColor: .systemGroupedBackground)
    static let cardBackground = Color.white
    static let accentPrimary = Color(hex: "#5648F5") ?? Color(uiColor: .systemIndigo)
    static let accentSecondary = Color(hex: "#7A6CF6") ?? Color(uiColor: .systemIndigo)
    static let success = Color(hex: "#2DBE7F") ?? Color(uiColor: .systemGreen)
    static let warning = Color(hex: "#FFB84D") ?? Color(uiColor: .systemOrange)
    static let danger = Color(hex: "#FF4D4D") ?? Color(uiColor: .systemRed)
    static let neutralText = Color(hex: "#4B5563") ?? Color(uiColor: .secondaryLabel)
    static let mutedText = Color(hex: "#94A3B8") ?? Color(uiColor: .tertiaryLabel)
    static let cardStroke = Color(hex: "#E3E8F4") ?? Color(uiColor: .systemGray5)
}

enum FinanceGradients {
    static let budgetCard = LinearGradient(
        gradient: Gradient(colors: [
            Color(hex: "#D8DDFE") ?? Color(uiColor: .systemIndigo).opacity(0.2),
            Color(hex: "#C9D6FF") ?? Color(uiColor: .systemBlue).opacity(0.2)
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cardBackground = LinearGradient(
        gradient: Gradient(colors: [
            Color.white,
            Color(hex: "#F1F5FF") ?? Color(uiColor: .systemGroupedBackground)
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

enum FinanceCorners {
    static let extraLarge: CGFloat = 36
    static let large: CGFloat = 28
    static let medium: CGFloat = 20
    static let small: CGFloat = 12
    static let pill: CGFloat = 999
}

enum FinanceShadows {
    static let card = Color.black.opacity(0.08)
}

enum FinanceSpacing {
    static let pageHorizontal: CGFloat = 20
    static let sectionSpacing: CGFloat = 18
    static let cardSpacing: CGFloat = 16
}

enum FinanceTypography {
    static func titleFont() -> Font { .system(size: 28, weight: .bold, design: .rounded) }
    static func sectionTitleFont() -> Font { .system(size: 20, weight: .semibold, design: .rounded) }
    static func bodyFont() -> Font { .system(size: 16, weight: .regular) }
    static func captionFont() -> Font { .system(size: 12, weight: .regular) }
}
