import SwiftUI

struct MediaHubTabView: View {

    @StateObject private var store = AppMediaStore()

    /// Закрыть хаб (например, dismiss sheet)
    var onClose: (() -> Void)? = nil

    /// Выбор эффекта → ты потом вернёшься в камеру и применишь shaderKey
    var onSelectEffect: (EffectItem) -> Void

    var body: some View {
        TabView {
            NavigationStack {
                RecordingsView()
                    .environmentObject(store)
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
                EffectsLibraryView { effect in
                    onSelectEffect(effect)
                    onClose?()
                }
                .environmentObject(store)
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
