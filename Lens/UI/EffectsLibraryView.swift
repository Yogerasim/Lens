import SwiftUI

struct EffectsLibraryView: View {

    @ObservedObject private var library = FilterLibrary.shared
    let onSelect: (FilterDefinition) -> Void

    var body: some View {
        List {
            ForEach(library.filters) { filter in
                Button {
                    onSelect(filter)
                } label: {
                    EffectRow(filter: filter)
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
    let filter: FilterDefinition

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(DesignSystem.Colors.lightGray.opacity(0.25))
                .frame(width: 52, height: 52)
                .overlay(
                    Image(systemName: filter.needsDepth ? "cube.transparent" : "sparkles")
                        .foregroundStyle(DesignSystem.Colors.blueUniversal)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(filter.name)
                    .font(DesignSystem.Fonts.semibold17)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                
                if filter.needsDepth {
                    Text("Использует LiDAR")
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
