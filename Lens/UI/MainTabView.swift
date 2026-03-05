import SwiftUI

// MARK: - MediaHubTabView (configurable tabs)

struct MediaHubTabView: View {

    // MARK: Dependencies

    var onClose: (() -> Void)? = nil
    var onSelectEffect: (FilterDefinition) -> Void

    var cameraManager: CameraManager
    var shaderManager: ShaderManager
    var mediaRecorder: MediaRecorder
    var framePipeline: FramePipeline

    // MARK: Tabs

    enum TabID: Int, CaseIterable, Hashable {
        case voice
        case effects
        case demo
        case recordings
    }

    struct TabItem: Identifiable, Hashable {
        let id: TabID
        var title: String
        var systemImage: String
        var isEnabled: Bool = true
    }

    static var defaultTabs: [TabItem] = [
        .init(id: .voice,   title: NSLocalizedString("tab_voice", comment: ""),   systemImage: "mic.fill",        isEnabled: true),
        .init(id: .effects, title: NSLocalizedString("tab_effects", comment: ""), systemImage: "wand.and.stars",  isEnabled: true),
        .init(id: .demo,    title: "Demo",                                         systemImage: "shuffle",        isEnabled: true),
    ]

    var tabs: [TabItem] = Self.defaultTabs

    // MARK: State

    @State private var selectedTab: TabID = .voice

    // MARK: Body

    var body: some View {
        let enabled = tabs.filter { $0.isEnabled }

        TabView(selection: $selectedTab) {
            ForEach(enabled) { tab in
                content(for: tab.id)
                    .tabItem {
                        Image(systemName: tab.systemImage)
                        Text(tab.title)
                    }
                    .tag(tab.id)
            }
        }
        .tint(DesignSystem.Colors.blueUniversal)
        .onAppear {
            if !enabled.contains(where: { $0.id == selectedTab }),
               let first = enabled.first?.id {
                selectedTab = first
            }
        }
        .onChange(of: tabs) { _, _ in
            let enabledNow = tabs.filter { $0.isEnabled }
            if !enabledNow.contains(where: { $0.id == selectedTab }),
               let first = enabledNow.first?.id {
                selectedTab = first
            }
        }
    }

    // MARK: Tab content

    @ViewBuilder
    private func content(for tab: TabID) -> some View {
        switch tab {

        case .voice:
            NavigationStack {
                VoiceComposerView(
                    cameraManager: cameraManager,
                    shaderManager: shaderManager,
                    mediaRecorder: mediaRecorder,
                    framePipeline: framePipeline
                )
            }

        case .effects:
            NavigationStack {
                EffectsLibraryView { filter in
                    onSelectEffect(filter)
                    onClose?()
                }
                .toolbar { closeAndTitleToolbar(title: NSLocalizedString("tab_effects", comment: "")) }
            }

        case .demo:
            NavigationStack {
                ShaderDemoControls()
                    .toolbar { closeAndTitleToolbar(title: "Demo") }
            }

        case .recordings:
            NavigationStack {
                RecordingsView()
                    .toolbar { closeAndTitleToolbar(title: NSLocalizedString("tab_recordings", comment: "")) }
            }
        }
    }

    // MARK: Toolbar builder

    @ToolbarContentBuilder
    private func closeAndTitleToolbar(title: String) -> some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button(NSLocalizedString("close", comment: "")) { onClose?() }
                .foregroundStyle(DesignSystem.Colors.textPrimary)
        }
        ToolbarItem(placement: .principal) {
            NavigationTitleView(title: title)
        }
    }
}

// MARK: - LegacyMediaHubTabView (also configurable)

struct LegacyMediaHubTabView: View {
    var onClose: (() -> Void)? = nil
    var onSelectEffect: (FilterDefinition) -> Void

    enum TabID: Int, CaseIterable, Hashable {
        case recordings
        case effects
    }

    struct TabItem: Identifiable, Hashable {
        let id: TabID
        var title: String
        var systemImage: String
        var isEnabled: Bool = true
    }

    static var defaultTabs: [TabItem] = [
        .init(id: .recordings, title: NSLocalizedString("tab_recordings", comment: ""), systemImage: "rectangle.stack", isEnabled: true),
        .init(id: .effects,    title: NSLocalizedString("tab_effects", comment: ""),    systemImage: "wand.and.stars", isEnabled: true),
    ]

    var tabs: [TabItem] = Self.defaultTabs
    @State private var selectedTab: TabID = .recordings

    var body: some View {
        let enabled = tabs.filter { $0.isEnabled }

        TabView(selection: $selectedTab) {
            ForEach(enabled) { tab in
                content(for: tab.id)
                    .tabItem {
                        Image(systemName: tab.systemImage)
                        Text(tab.title)
                    }
                    .tag(tab.id)
            }
        }
        .tint(DesignSystem.Colors.blueUniversal)
        .onAppear {
            if !enabled.contains(where: { $0.id == selectedTab }),
               let first = enabled.first?.id {
                selectedTab = first
            }
        }
        .onChange(of: tabs) { _, _ in
            let enabledNow = tabs.filter { $0.isEnabled }
            if !enabledNow.contains(where: { $0.id == selectedTab }),
               let first = enabledNow.first?.id {
                selectedTab = first
            }
        }
    }

    @ViewBuilder
    private func content(for tab: TabID) -> some View {
        switch tab {
        case .recordings:
            NavigationStack {
                RecordingsView()
                    .toolbar { closeAndTitleToolbar(title: NSLocalizedString("tab_recordings", comment: "")) }
            }

        case .effects:
            NavigationStack {
                EffectsLibraryView { filter in
                    onSelectEffect(filter)
                    onClose?()
                }
                .toolbar { closeAndTitleToolbar(title: NSLocalizedString("tab_effects", comment: "")) }
            }
        }
    }

    @ToolbarContentBuilder
    private func closeAndTitleToolbar(title: String) -> some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button(NSLocalizedString("close", comment: "")) { onClose?() }
                .foregroundStyle(DesignSystem.Colors.textPrimary)
        }
        ToolbarItem(placement: .principal) {
            NavigationTitleView(title: title)
        }
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
