import SwiftUI

struct MediaHubTabView: View {

    var onClose: (() -> Void)? = nil
    var onSelectEffect: (FilterDefinition) -> Void

    var cameraManager: CameraManager
    var shaderManager: ShaderManager
    var mediaRecorder: MediaRecorder
    var framePipeline: FramePipeline

    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {

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

            NavigationStack {
                ShaderDemoControls()
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button(NSLocalizedString("close", comment: "")) { onClose?() }
                                .foregroundStyle(DesignSystem.Colors.textPrimary)
                        }
                        ToolbarItem(placement: .principal) {
                            NavigationTitleView(title: "Demo")
                        }
                    }
            }
            .tabItem {
                Image(systemName: "shuffle")
                Text("Demo")
            }
            .tag(2)
        }
        .tint(DesignSystem.Colors.blueUniversal)
    }
}

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
