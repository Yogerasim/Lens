import SwiftUI

// MARK: - Liquid Glass Tokens

enum GlassToken {
    static let corner: CGFloat = 18
    static let strokeOpacity: CGFloat = 0.22
    static let highlightOpacity: CGFloat = 0.35
    static let shadowOpacity: CGFloat = 0.20
    static let shadowRadius: CGFloat = 18
    static let shadowY: CGFloat = 10
}

// MARK: - Glass Panel (карточки/плашки)

struct GlassPanel: ViewModifier {
    var cornerRadius: CGFloat = GlassToken.corner
    var padding: CGFloat = 10

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(GlassToken.strokeOpacity), lineWidth: 1)
            )
            .shadow(color: .black.opacity(GlassToken.shadowOpacity),
                    radius: GlassToken.shadowRadius,
                    x: 0,
                    y: GlassToken.shadowY)
    }
}

extension View {
    func glassPanel(cornerRadius: CGFloat = GlassToken.corner, padding: CGFloat = 10) -> some View {
        modifier(GlassPanel(cornerRadius: cornerRadius, padding: padding))
    }
}

// MARK: - Glass Button Style (универсальный стиль кнопок)

struct GlassButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = 16
    var horizontalPadding: CGFloat = 14
    var verticalPadding: CGFloat = 10

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(GlassToken.strokeOpacity), lineWidth: 1)
            )
            .overlay(
                // лёгкий "жидкий" хайлайт при нажатии
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.white.opacity(configuration.isPressed ? 0.10 : 0.0))
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .shadow(color: .black.opacity(0.18),
                    radius: configuration.isPressed ? 10 : 18,
                    x: 0,
                    y: configuration.isPressed ? 6 : 10)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == GlassButtonStyle {
    static var glass: GlassButtonStyle { .init() }
}

// MARK: - Glass Circle Icon Button (иконки в кружке)

struct GlassCircleIcon: ViewModifier {
    var size: CGFloat = 54

    func body(content: Content) -> some View {
        content
            .frame(width: size, height: size)
            .background(.ultraThinMaterial)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(.white.opacity(GlassToken.strokeOpacity), lineWidth: 1))
            .shadow(color: .black.opacity(0.18), radius: 16, x: 0, y: 10)
    }
}

extension View {
    func glassCircle(size: CGFloat = 54) -> some View {
        modifier(GlassCircleIcon(size: size))
    }
}

// MARK: - Glass Chip (маленькие пилюли: 0.5 / 1x / 2x)

struct GlassChip: ViewModifier {
    var isSelected: Bool

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(GlassToken.strokeOpacity), lineWidth: 1))
            .overlay(
                Capsule()
                    .fill(.white.opacity(isSelected ? 0.12 : 0.0))
            )
            .shadow(color: .black.opacity(0.14), radius: 14, x: 0, y: 8)
    }
}

extension View {
    func glassChip(isSelected: Bool) -> some View {
        modifier(GlassChip(isSelected: isSelected))
    }
}
