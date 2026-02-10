import SwiftUI

enum DesignSystem {
    enum Colors {
        static let blueUniversal = Color(hex: "#3772E7")
        static let redUniversal = Color(hex: "#F56B6C")
        static let lightGray = Color(hex: "#EEEEEE")

        static let background = Color("AppBackground")
        static let textPrimary = Color("TextPrimary")
    }

    enum Fonts {
        static func regular(_ size: CGFloat) -> Font {
            .system(size: size, weight: .regular)
        }

        static func medium(_ size: CGFloat) -> Font {
            .system(size: size, weight: .medium)
        }

        static func semibold(_ size: CGFloat) -> Font {
            .system(size: size, weight: .semibold)
        }

        static func bold(_ size: CGFloat) -> Font {
            .system(size: size, weight: .bold)
        }

        static let bold17 = bold(17)
        static let bold34 = bold(34)
        static let bold24 = bold(24)
        static let medium17 = medium(17)
        static let medium12 = medium(12)
        static let regular14 = regular(14)
        static let regular17 = regular(17)
        static let regular20 = regular(20)
        static let regular12 = regular(12)
        static let semibold17 = semibold(17)
        static let medium15 = medium(15)
        static let bold19 = bold(19)
    }
}

extension Color {
    init(hex: String, opacity: Double = 1.0) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b) = (int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: opacity
        )
    }
}
