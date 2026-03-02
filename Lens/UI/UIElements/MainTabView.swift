import SwiftUI

// MARK: - Main Hub (Short tap) — Voice + Effects tabs
struct MediaHubTabView: View {

    var onClose: (() -> Void)? = nil
    var onSelectEffect: (FilterDefinition) -> Void

    // Dependencies for Voice tab
    var cameraManager: CameraManager
    var shaderManager: ShaderManager
    var mediaRecorder: MediaRecorder
    var framePipeline: FramePipeline

    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1 — Voice Assistant (главный вход)
            NavigationStack {
                VoiceComposerView(
                    cameraManager: cameraManager,
                    shaderManager: shaderManager,
                    mediaRecorder: mediaRecorder,
                    framePipeline: framePipeline
                )
            }
            .tabItem {
                Image(systemName: "mic.fill")
                Text(NSLocalizedString("tab_voice", comment: ""))
            }
            .tag(0)

            // Tab 2 — Effects Library
            NavigationStack {
                EffectsLibraryView { filter in
                    onSelectEffect(filter)
                    onClose?()
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(NSLocalizedString("close", comment: "")) { onClose?() }
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                    }
                    ToolbarItem(placement: .principal) {
                        NavigationTitleView(title: NSLocalizedString("tab_effects", comment: ""))
                    }
                }
            }
            .tabItem {
                Image(systemName: "wand.and.stars")
                Text(NSLocalizedString("tab_effects", comment: ""))
            }
            .tag(1)
        }
        .tint(DesignSystem.Colors.blueUniversal)
    }
}

// MARK: - Legacy Hub (Long tap) — Recordings + Effects
// TODO: unused for now — kept for legacy compatibility
struct LegacyMediaHubTabView: View {
    var onClose: (() -> Void)? = nil
    var onSelectEffect: (FilterDefinition) -> Void

    var body: some View {
        TabView {
            NavigationStack {
                RecordingsView()
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button(NSLocalizedString("close", comment: "")) { onClose?() }
                                .foregroundStyle(DesignSystem.Colors.textPrimary)
                        }
                        ToolbarItem(placement: .principal) {
                            NavigationTitleView(title: NSLocalizedString("tab_recordings", comment: ""))
                        }
                    }
            }
            .tabItem {
                Image(systemName: "rectangle.stack")
                Text(NSLocalizedString("tab_recordings", comment: ""))
            }

            NavigationStack {
                EffectsLibraryView { filter in
                    onSelectEffect(filter)
                    onClose?()
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(NSLocalizedString("close", comment: "")) { onClose?() }
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                    }
                    ToolbarItem(placement: .principal) {
                        NavigationTitleView(title: NSLocalizedString("tab_effects", comment: ""))
                    }
                }
            }
            .tabItem {
                Image(systemName: "wand.and.stars")
                Text(NSLocalizedString("tab_effects", comment: ""))
            }
        }
        .tint(DesignSystem.Colors.blueUniversal)
    }
}

#Preview {
    MediaHubTabView(
        onClose: {},
        onSelectEffect: { _ in },
        cameraManager: CameraManager(),
        shaderManager: ShaderManager.shared,
        mediaRecorder: MediaRecorder(),
        framePipeline: FramePipeline.shared
    )
}
