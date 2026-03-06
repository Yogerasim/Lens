import SwiftUI

struct EffectsLibraryView: View {

  @ObservedObject private var library = FilterLibrary.shared
  @ObservedObject private var framePipeline = FramePipeline.shared
  @ObservedObject private var graphStore = EffectGraphStore.shared
  @ObservedObject private var graphSession = GraphSessionController.shared

  let onSelect: (FilterDefinition) -> Void

  private var availableFilters: [FilterDefinition] {
    let isFront = framePipeline.cameraManager?.isFrontCamera ?? false
    let isRecording = framePipeline.isRecording
    let recordingFamily = framePipeline.recordingFilterFamily

    return library.availableFilters(
      isFront: isFront,
      recordingFamily: recordingFamily,
      isRecording: isRecording
    ).filter { $0.shaderName != "fragment_universalgraph" }
  }

  var body: some View {
    List {

      if framePipeline.isRecording, let family = framePipeline.recordingFilterFamily {
        HStack {
          Image(systemName: "record.circle.fill")
            .foregroundColor(.red)
          Text("Locked to \(family.rawValue) filters")
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .listRowBackground(Color.clear)
      }

      Section("Built-in Effects") {
        ForEach(availableFilters) { filter in
          Button {
            onSelect(filter)
          } label: {
            EffectRow(filter: filter)
          }
          .buttonStyle(.plain)
          .listRowBackground(DesignSystem.Colors.background)
        }
      }

      if !graphStore.graphs.isEmpty {
        Section("My Effects") {
          ForEach(graphStore.graphs) { graph in
            Button {
              selectCustomGraph(graph)
            } label: {
              CustomGraphRow(graph: graph, isSelected: graphSession.selectedGraphId == graph.id)
            }
            .buttonStyle(.plain)
            .listRowBackground(DesignSystem.Colors.background)
          }
          .onDelete(perform: deleteGraph)
        }
      }
    }
    .listStyle(.plain)
    .scrollContentBackground(.hidden)
    .background(DesignSystem.Colors.background)
  }

  private func selectCustomGraph(_ graph: EffectGraph) {
    _ = graphSession.selectGraph(graph)

    if let customFilter = library.filters.first(where: {
      $0.shaderName == "fragment_universalgraph"
    }) {
      onSelect(customFilter)
    }
  }

  private func deleteGraph(at offsets: IndexSet) {
    for index in offsets {
      let graph = graphStore.graphs[index]
      graphStore.remove(id: graph.id)
    }
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

        HStack(spacing: 8) {
          if filter.needsDepth {
            Label("LiDAR", systemImage: "sensor.tag.radiowaves.forward")
              .font(DesignSystem.Fonts.regular12)
              .foregroundStyle(DesignSystem.Colors.textPrimary.opacity(0.65))
          }

          if filter.supportsIntensity {
            Label("Intensity", systemImage: "slider.horizontal.3")
              .font(DesignSystem.Fonts.regular12)
              .foregroundStyle(DesignSystem.Colors.textPrimary.opacity(0.5))
          }
        }
      }

      Spacer()

      Image(systemName: "chevron.right")
        .foregroundStyle(DesignSystem.Colors.textPrimary.opacity(0.35))
    }
    .padding(.vertical, 8)
  }
}

private struct CustomGraphRow: View {
  let graph: EffectGraph
  let isSelected: Bool

  var body: some View {
    HStack(spacing: 12) {

      ZStack {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .fill(
            isSelected
              ? DesignSystem.Colors.blueUniversal.opacity(0.3)
              : DesignSystem.Colors.lightGray.opacity(0.25)
          )
          .frame(width: 52, height: 52)

        VStack(spacing: 2) {
          Image(systemName: "square.stack.3d.up.fill")
            .font(.title3)
            .foregroundStyle(DesignSystem.Colors.blueUniversal)

          Text("\(graph.nodes.count)")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(DesignSystem.Colors.textPrimary.opacity(0.7))
        }
      }

      VStack(alignment: .leading, spacing: 4) {
        HStack {
          Text(graph.name)
            .font(DesignSystem.Fonts.semibold17)
            .foregroundStyle(DesignSystem.Colors.textPrimary)

          if isSelected {
            Image(systemName: "checkmark.circle.fill")
              .foregroundColor(.green)
              .font(.caption)
          }
        }

        if let mix = graph.mix {
          HStack(spacing: 4) {
            Image(systemName: "arrow.triangle.merge")
              .font(.caption2)
            Text("\(mix.effectA) + \(mix.effectB)")
          }
          .font(DesignSystem.Fonts.regular12)
          .foregroundStyle(DesignSystem.Colors.blueUniversal.opacity(0.8))
          .lineLimit(1)
        }

        if !graph.nodes.isEmpty {
          HStack(spacing: 4) {
            ForEach(graph.nodes.prefix(4)) { node in
              Image(systemName: node.type.icon)
                .font(.caption2)
            }
            if graph.nodes.count > 4 {
              Text("+\(graph.nodes.count - 4)")
                .font(.caption2)
            }
          }
          .foregroundStyle(DesignSystem.Colors.textPrimary.opacity(0.5))
        }

        if graph.needsDepth {
          Label("LiDAR", systemImage: "sensor.tag.radiowaves.forward")
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
