import SwiftUI

struct GlassIntensityHUD: View {

  let value: Float

  let isVisible: Bool

  private let hudWidth: CGFloat = 40
  private let hudHeight: CGFloat = 160
  private let cornerRadius: CGFloat = 20
  private let fillPadding: CGFloat = 6
  private let fillCornerRadius: CGFloat = 14

  var body: some View {
    ZStack {

      RoundedRectangle(cornerRadius: cornerRadius)
        .fill(.ultraThinMaterial)
        .overlay(
          RoundedRectangle(cornerRadius: cornerRadius)
            .strokeBorder(
              LinearGradient(
                colors: [
                  Color.white.opacity(0.4),
                  Color.white.opacity(0.1),
                ],
                startPoint: .top,
                endPoint: .bottom
              ),
              lineWidth: 0.5
            )
        )
        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 4)

      VStack(spacing: 8) {

        Text("\(Int(value * 100))")
          .font(.system(size: 14, weight: .semibold, design: .rounded))
          .foregroundStyle(.white)
          .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)

        ZStack(alignment: .bottom) {

          Capsule()
            .fill(Color.white.opacity(0.15))
            .frame(width: 8)

          Capsule()
            .fill(
              LinearGradient(
                colors: intensityGradientColors,
                startPoint: .bottom,
                endPoint: .top
              )
            )
            .frame(width: 8, height: max(4, CGFloat(value) * (hudHeight - 60)))
            .shadow(color: intensityGlowColor.opacity(0.6), radius: 4, x: 0, y: 0)
        }
        .frame(height: hudHeight - 60)

        Image(systemName: intensityIcon)
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(.white.opacity(0.7))
      }
      .padding(.vertical, 12)
    }
    .frame(width: hudWidth, height: hudHeight)
    .opacity(isVisible ? 1 : 0)
    .scaleEffect(isVisible ? 1 : 0.8)
    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isVisible)
    .animation(.easeOut(duration: 0.1), value: value)
  }

  private var intensityGradientColors: [Color] {
    if value < 0.3 {
      return [Color.gray.opacity(0.6), Color.gray.opacity(0.3)]
    } else if value < 0.7 {
      return [Color.cyan, Color.blue.opacity(0.6)]
    } else {
      return [Color.cyan, Color.white.opacity(0.9)]
    }
  }

  private var intensityGlowColor: Color {
    value > 0.5 ? .cyan : .white
  }

  private var intensityIcon: String {
    if value < 0.1 {
      return "circle"
    } else if value < 0.5 {
      return "circle.lefthalf.filled"
    } else {
      return "circle.fill"
    }
  }
}

#Preview {
  ZStack {
    Color.black.ignoresSafeArea()

    HStack(spacing: 20) {
      GlassIntensityHUD(value: 0.0, isVisible: true)
      GlassIntensityHUD(value: 0.3, isVisible: true)
      GlassIntensityHUD(value: 0.7, isVisible: true)
      GlassIntensityHUD(value: 1.0, isVisible: true)
    }
  }
}
