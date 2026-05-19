import SwiftUI

enum CTTheme {
    static let primary = Color(hex: 0x181D26)
    static let primaryActive = Color(hex: 0x0D1218)
    static let ink = Color(hex: 0x181D26)
    static let body = Color(hex: 0x333840)
    static let muted = Color(hex: 0x41454D)
    static let hairline = Color(hex: 0xDDDDDD)
    static let borderStrong = Color(hex: 0x9297A0)
    static let canvas = Color.white
    static let surfaceSoft = Color(hex: 0xF8FAFC)
    static let surfaceStrong = Color(hex: 0xE0E2E6)
    static let surfaceDark = Color(hex: 0x181D26)
    static let coral = Color(hex: 0xAA2D00)
    static let forest = Color(hex: 0x0A2E0E)
    static let cream = Color(hex: 0xF5E9D4)
    static let peach = Color(hex: 0xFCAB79)
    static let mint = Color(hex: 0xA8D8C4)
    static let yellow = Color(hex: 0xF4D35E)
    static let link = Color(hex: 0x1B61C9)
    static let success = Color(hex: 0x006400)
    static let warning = Color(hex: 0xD9A441)

    enum Radius {
        static let xs: CGFloat = 2
        static let sm: CGFloat = 6
        static let md: CGFloat = 10
        static let lg: CGFloat = 12
        static let pill: CGFloat = 999
    }

    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
        static let section: CGFloat = 96
    }

    enum Typography {
        static let display = Font.system(size: 40, weight: .regular, design: .default)
        static let displayMedium = Font.system(size: 32, weight: .regular, design: .default)
        static let title = Font.system(size: 24, weight: .regular, design: .default)
        static let titleSmall = Font.system(size: 18, weight: .medium, design: .default)
        static let label = Font.system(size: 16, weight: .medium, design: .default)
        static let button = Font.system(size: 16, weight: .medium, design: .default)
        static let body = Font.system(size: 14, weight: .regular, design: .default)
        static let caption = Font.system(size: 13, weight: .medium, design: .default)
        static let reader = Font.custom("Inter", size: 15)
    }
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 08) & 0xff) / 255,
            blue: Double((hex >> 00) & 0xff) / 255,
            opacity: alpha
        )
    }
}
