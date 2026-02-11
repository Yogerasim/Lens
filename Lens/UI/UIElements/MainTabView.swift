import SwiftUI

struct MediaHubTabView: View {

    /// Закрыть хаб (например, dismiss sheet)
    var onClose: (() -> Void)? = nil

    /// Выбор эффекта → применить фильтр в камере
    var onSelectEffect: (FilterDefinition) -> Void

    var body: some View {
        TabView {
            NavigationStack {
                RecordingsView()
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Закрыть") { onClose?() }
                                .foregroundStyle(DesignSystem.Colors.textPrimary)
                        }
                        ToolbarItem(placement: .principal) {
                            NavigationTitleView(title: "Записи")
                        }
                    }
            }
            .tabItem {
                Image(systemName: "rectangle.stack")
                Text("Записи")
            }

            NavigationStack {
                EffectsLibraryView { filter in
                    onSelectEffect(filter)
                    onClose?()
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Закрыть") { onClose?() }
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                    }
                    ToolbarItem(placement: .principal) {
                        NavigationTitleView(title: "Эффекты")
                    }
                }
            }
            .tabItem {
                Image(systemName: "wand.and.stars")
                Text("Эффекты")
            }
        }
        .tint(DesignSystem.Colors.blueUniversal)
    }
}

#Preview {
    MediaHubTabView(onClose: {}, onSelectEffect: { _ in })
}
