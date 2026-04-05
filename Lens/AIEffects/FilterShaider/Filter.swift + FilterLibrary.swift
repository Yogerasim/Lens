import Combine
import Foundation

struct FilterDefinition: Identifiable, Codable, Hashable {
  let id: UUID
  let name: String
  let shaderName: String
  let iconName: String
  let previewImageName: String?
  let needsDepth: Bool
  let supportsIntensity: Bool
  let isPremium: Bool
  let category: EffectCardCategory

  init(
    id: UUID = UUID(),
    name: String,
    shaderName: String,
    iconName: String = "sparkles",
    previewImageName: String? = nil,
    needsDepth: Bool = false,
    supportsIntensity: Bool = true,
    isPremium: Bool = false,
    category: EffectCardCategory = .stylized
  ) {
    self.id = id
    self.name = name
    self.shaderName = shaderName
    self.iconName = iconName
    self.previewImageName = previewImageName
    self.needsDepth = needsDepth
    self.supportsIntensity = supportsIntensity
    self.isPremium = isPremium
    self.category = category
  }
}

final class FilterLibrary: ObservableObject {
  static let shared = FilterLibrary()

  @Published private(set) var filters: [FilterDefinition] = []

  private init() {
    filters = ShaderRegistry.all.map {
      FilterDefinition(
        name: $0.displayName,
        shaderName: $0.fragment,
        iconName: $0.icon,
        previewImageName: $0.previewImageName,
        needsDepth: $0.needsDepth,
        supportsIntensity: $0.supportsIntensity,
        isPremium: $0.isPremium,
        category: $0.category
      )
    }
  }

  func filter(for shaderName: String) -> FilterDefinition? {
    filters.first { $0.shaderName == shaderName }
  }

  func firstNonDepthFilter() -> FilterDefinition? {
    filters.first { !$0.needsDepth }
  }

  func firstDepthFilter() -> FilterDefinition? {
    filters.first { $0.needsDepth }
  }

  func availableFilters(
    isFront: Bool,
    depthSupported: Bool = true,
    recordingFamily: FilterFamily? = nil,
    isRecording: Bool = false
  ) -> [FilterDefinition] {

    var available = filters

    if isFront {
      available = available.filter { !$0.needsDepth }
    } else if isRecording, let family = recordingFamily {
      switch family {
      case .depth:
        available = available.filter { $0.needsDepth }
      case .nonDepth:
        available = available.filter { !$0.needsDepth }
      }
    } else if !depthSupported {
      available = available.filter { !$0.needsDepth }
    }

    return available
  }
}
