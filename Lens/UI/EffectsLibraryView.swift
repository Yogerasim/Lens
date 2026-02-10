import SwiftUI

struct EffectsLibraryView: View {

    @EnvironmentObject private var store: AppMediaStore
    let onSelect: (EffectItem) -> Void

    var body: some View {
        List {
            ForEach(store.effects) { effect in
                Button {
                    onSelect(effect)
                } label: {
                    EffectRow(effect: effect)
                }
                .buttonStyle(.plain)
                .listRowBackground(DesignSystem.Colors.background)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(DesignSystem.Colors.background)
    }
}

private struct EffectRow: View {
    let effect: EffectItem

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(DesignSystem.Colors.lightGray.opacity(0.25))
                .frame(width: 52, height: 52)
                .overlay(
                    Image(systemName: "sparkles")
                        .foregroundStyle(DesignSystem.Colors.blueUniversal)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(effect.title)
                    .font(DesignSystem.Fonts.semibold17)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                if let subtitle = effect.subtitle {
                    Text(subtitle)
                        .font(DesignSystem.Fonts.regular12)
                        .foregroundStyle(DesignSystem.Colors.textPrimary.opacity(0.65))
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(DesignSystem.Colors.textPrimary.opacity(0.35))
        }
        .padding(.vertical, 8)
    }
}
