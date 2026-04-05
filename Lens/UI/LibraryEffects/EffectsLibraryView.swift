import SwiftUI

struct EffectsLibraryView: View {

  @ObservedObject private var library = FilterLibrary.shared
  @ObservedObject private var framePipeline = FramePipeline.shared
  @ObservedObject private var graphStore = EffectGraphStore.shared
  @ObservedObject private var graphSession = GraphSessionController.shared
  @ObservedObject private var shaderManager = ShaderManager.shared

  let onSelect: (FilterDefinition) -> Void
    
    private let columns = [
      GridItem(.adaptive(minimum: 100, maximum: 140), spacing: 10)
    ]

//  private let columns = [
//    GridItem(.flexible(), spacing: 10),
//    GridItem(.flexible(), spacing: 10),
//    GridItem(.flexible(), spacing: 10)
//  ]

  private let orderedSections: [EffectCardCategory] = [
    .pro,
    .depth,
    .outline,
    .stylized
  ]

  private var availableFilters: [FilterDefinition] {
    let isFront = framePipeline.cameraManager?.isFrontCamera ?? false
    let isRecording = framePipeline.isRecording
    let recordingFamily = framePipeline.recordingFilterFamily

    return library.availableFilters(
      isFront: isFront,
      recordingFamily: recordingFamily,
      isRecording: isRecording
    )
    .filter { $0.shaderName != ShaderRegistry.customGraphFragment }
  }

  var body: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 18) {

        if framePipeline.isRecording, let family = framePipeline.recordingFilterFamily {
          recordingInfo(family: family)
        }

        if hasPremiumSection {
          sectionTitle("PRO")
          cardsGrid(filtersInSection(.pro))
        }

        if !graphStore.graphs.isEmpty {
          sectionTitle("My Effects")
          myEffectsGrid
        }

        ForEach(orderedSections.filter { $0 != .pro }, id: \.self) { section in
          let sectionFilters = filtersInSection(section)

          if !sectionFilters.isEmpty {
            sectionTitle(section.title)
            cardsGrid(sectionFilters)
          }
        }
      }
      .padding(.horizontal, 16)
      .padding(.top, 12)
      .padding(.bottom, 32)
    }
    .scrollIndicators(.hidden)
    .background(DesignSystem.Colors.background.ignoresSafeArea())
  }

  private var hasPremiumSection: Bool {
    !filtersInSection(.pro).isEmpty
  }

  @ViewBuilder
  private func cardsGrid(_ filters: [FilterDefinition]) -> some View {
    LazyVGrid(columns: columns, spacing: 10) {
      ForEach(filters) { filter in
        Button {
          onSelect(filter)
        } label: {
          EffectCardView(
            title: filter.name,
            subtitle: subtitle(for: filter.category),
            previewImageName: filter.previewImageName,
            systemImageName: filter.iconName,
            isSelected: shaderManager.currentFragment == filter.shaderName,
            needsDepth: filter.needsDepth,
            supportsIntensity: filter.supportsIntensity,
            isPremium: filter.isPremium,
            isLocked: filter.isPremium,
            category: filter.category
          )
        }
        .buttonStyle(.plain)
      }
    }
  }

  private var myEffectsGrid: some View {
    LazyVGrid(columns: columns, spacing: 10) {
      ForEach(graphStore.graphs) { graph in
        Button {
          selectCustomGraph(graph)
        } label: {
          EffectCardView(
            title: graph.name,
            subtitle: graph.mix.map { "\($0.effectA) + \($0.effectB)" } ?? "Custom graph",
            previewImageName: nil,
            systemImageName: "square.stack.3d.up.fill",
            isSelected: graphSession.selectedGraphId == graph.id,
            needsDepth: graph.needsDepth,
            supportsIntensity: true,
            isPremium: false,
            isLocked: false,
            category: .myEffects,
            nodeCount: graph.nodes.count
          )
        }
        .buttonStyle(.plain)
        .contextMenu {
          Button(role: .destructive) {
            graphStore.remove(id: graph.id)
          } label: {
            Label("Delete", systemImage: "trash")
          }
        }
      }
    }
  }

  private func filtersInSection(_ category: EffectCardCategory) -> [FilterDefinition] {
    availableFilters.filter { $0.category == category }
  }

  private func subtitle(for category: EffectCardCategory) -> String? {
    switch category {
    case .pro:
      return "Premium"
    case .depth:
      return "Depth-based"
    case .outline:
      return "Outline"
    case .stylized:
      return "Stylized"
    case .myEffects:
      return "Custom"
    }
  }

  private func selectCustomGraph(_ graph: EffectGraph) {
    _ = graphSession.selectGraph(graph)

    if let customFilter = library.filters.first(where: {
      $0.shaderName == ShaderRegistry.customGraphFragment
    }) {
      onSelect(customFilter)
    }
  }

  @ViewBuilder
  private func sectionTitle(_ title: String) -> some View {
    Text(title)
      .font(DesignSystem.Fonts.semibold17)
      .foregroundStyle(DesignSystem.Colors.textPrimary)
      .padding(.horizontal, 2)
  }

  @ViewBuilder
  private func recordingInfo(family: FilterFamily) -> some View {
    HStack(spacing: 8) {
      Image(systemName: "record.circle.fill")
        .foregroundStyle(.red)

      Text("Locked to \(family.rawValue) filters")
        .font(DesignSystem.Fonts.regular12)
        .foregroundStyle(DesignSystem.Colors.textPrimary.opacity(0.7))
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .background(
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .fill(DesignSystem.Colors.lightGray.opacity(0.12))
    )
  }
}
