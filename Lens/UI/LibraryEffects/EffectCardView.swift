import SwiftUI

struct EffectCardView: View {
  let title: String
  let subtitle: String?
  let previewImageName: String?
  let systemImageName: String
  let isSelected: Bool
  let needsDepth: Bool
  let supportsIntensity: Bool
  let isPremium: Bool
  let isUnlocked: Bool
  let category: EffectCardCategory?
  var nodeCount: Int? = nil

  private let cardCornerRadius: CGFloat = 16
  private let previewCornerRadius: CGFloat = 14
  private let previewHeight: CGFloat = 92

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      previewBlock
      infoBlock
    }
    .background(cardBackground)
    .overlay(cardStroke)
    .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
    .contentShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
  }

  private var cardBackground: some View {
    RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
      .fill(DesignSystem.Colors.lightGray.opacity(0.12))
  }

  private var cardStroke: some View {
    RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
      .stroke(
        isSelected
          ? DesignSystem.Colors.blueUniversal.opacity(0.9)
          : DesignSystem.Colors.textPrimary.opacity(0.08),
        lineWidth: isSelected ? 1.25 : 1
      )
  }

  private var previewBlock: some View {
    ZStack {
      RoundedRectangle(cornerRadius: previewCornerRadius, style: .continuous)
        .fill(DesignSystem.Colors.lightGray.opacity(0.18))

      previewContent
        .clipShape(RoundedRectangle(cornerRadius: previewCornerRadius, style: .continuous))

      VStack {
        HStack {
          topLeftBadge
          Spacer()
          topRightBadges
        }

        Spacer()

        HStack {
          bottomLeftBadges
          Spacer()
        }
      }
      .padding(7)
    }
    .frame(height: previewHeight)
    .padding(7)
  }

  @ViewBuilder
  private var previewContent: some View {
    if let previewImageName {
      GeometryReader { geometry in
        Image(previewImageName)
          .resizable()
          .scaledToFill()
          .frame(width: geometry.size.width, height: geometry.size.height)
          .clipped()
      }
    } else {
      fallbackPreview
    }
  }

  private var fallbackPreview: some View {
    ZStack {
      LinearGradient(
        colors: gradientColors,
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )

      VStack(spacing: 6) {
        Image(systemName: systemImageName)
          .font(.system(size: 22, weight: .semibold))
          .foregroundStyle(DesignSystem.Colors.blueUniversal)

        if let nodeCount {
          Text("\(nodeCount) nodes")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(DesignSystem.Colors.textPrimary.opacity(0.68))
        }
      }
    }
  }

  private var gradientColors: [Color] {
    if isPremium {
      return [
        DesignSystem.Colors.blueUniversal.opacity(0.26),
        DesignSystem.Colors.lightGray.opacity(0.20),
        DesignSystem.Colors.blueUniversal.opacity(0.12)
      ]
    }

    if needsDepth {
      return [
        DesignSystem.Colors.blueUniversal.opacity(0.24),
        DesignSystem.Colors.lightGray.opacity(0.18),
        DesignSystem.Colors.blueUniversal.opacity(0.08)
      ]
    }

    return [
      DesignSystem.Colors.lightGray.opacity(0.30),
      DesignSystem.Colors.blueUniversal.opacity(0.18),
      DesignSystem.Colors.lightGray.opacity(0.16)
    ]
  }

  @ViewBuilder
  private var topLeftBadge: some View {
    if let category {
      switch category {
      case .outline:
        badge("OUTLINE", systemImage: "scribble.variable")
      case .stylized:
        badge("STYLE", systemImage: "sparkles")
      case .myEffects:
        badge("MY", systemImage: "square.stack.3d.up.fill")
      case .depth, .pro:
        EmptyView()
      }
    }
  }

  @ViewBuilder
  private var topRightBadges: some View {
    HStack(spacing: 4) {
      if isPremium {
        badge("PRO", systemImage: "crown.fill")
      }

      if isPremium && !isUnlocked {
        badge(nil, systemImage: "lock.fill")
      }
    }
  }

  @ViewBuilder
  private var bottomLeftBadges: some View {
    HStack(spacing: 4) {
      if needsDepth {
        badge("LiDAR", systemImage: "sensor.tag.radiowaves.forward")
      }

      if supportsIntensity {
        badge(nil, systemImage: "slider.horizontal.3")
      }
    }
  }

  private var infoBlock: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(DesignSystem.Colors.textPrimary)
        .lineLimit(2)
        .fixedSize(horizontal: false, vertical: true)

      if let subtitle, !subtitle.isEmpty {
        Text(subtitle)
          .font(.system(size: 11, weight: .regular))
          .foregroundStyle(DesignSystem.Colors.textPrimary.opacity(0.58))
          .lineLimit(1)
      }
    }
    .padding(.horizontal, 10)
    .padding(.bottom, 10)
    .padding(.top, 1)
  }

  private func badge(_ title: String?, systemImage: String) -> some View {
    HStack(spacing: 3) {
      Image(systemName: systemImage)
        .font(.system(size: 9, weight: .semibold))

      if let title {
        Text(title)
          .font(.system(size: 9, weight: .semibold))
      }
    }
    .foregroundStyle(.white)
    .padding(.horizontal, 6)
    .padding(.vertical, 4)
    .background(.black.opacity(0.52))
    .clipShape(Capsule())
  }
}

#Preview("Compact 3-column cards") {
  ScrollView {
    LazyVGrid(
      columns: [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
      ],
      spacing: 10
    ) {
      EffectCardView(
        title: "Comic",
        subtitle: "Outline",
        previewImageName: "comic",
        systemImageName: "paintbrush.fill",
        isSelected: true,
        needsDepth: false,
        supportsIntensity: true,
        isPremium: false,
        isUnlocked: true,
        category: .outline
      )

      EffectCardView(
        title: "Depth Solid",
        subtitle: "Depth-based",
        previewImageName: "depthSolid",
        systemImageName: "cube.transparent",
        isSelected: false,
        needsDepth: true,
        supportsIntensity: true,
        isPremium: false,
        isUnlocked: true,
        category: .depth
      )

      EffectCardView(
        title: "Kaleidoscope Pro",
        subtitle: "Premium",
        previewImageName: "kaleidoscope",
        systemImageName: "hexagon.grid.fill",
        isSelected: false,
        needsDepth: false,
        supportsIntensity: true,
        isPremium: true,
        isUnlocked: false,
        category: .pro
      )

      EffectCardView(
        title: "My Dream FX",
        subtitle: "Custom graph",
        previewImageName: nil,
        systemImageName: "square.stack.3d.up.fill",
        isSelected: false,
        needsDepth: false,
        supportsIntensity: true,
        isPremium: false,
        isUnlocked: true,
        category: .myEffects,
        nodeCount: 6
      )
    }
    .padding(16)
  }
  .background(DesignSystem.Colors.background)
}
