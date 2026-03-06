import Foundation

enum NodeType: String, Codable, CaseIterable, Hashable {
  case grain  // Зернистость/шум
  case outline  // Контуры (Sobel)
  case blur  // Размытие
  case colorShift  // Сдвиг цвета
  case vignette  // Виньетка
  case fogDepth  // Туман по глубине (needsDepth)
  case stripes  // Полоски/штрихи

  var needsDepth: Bool {
    switch self {
    case .fogDepth:
      return true
    default:
      return false
    }
  }

  var displayName: String {
    switch self {
    case .grain: return "Зерно"
    case .outline: return "Контур"
    case .blur: return "Размытие"
    case .colorShift: return "Сдвиг цвета"
    case .vignette: return "Виньетка"
    case .fogDepth: return "Туман глубины"
    case .stripes: return "Полоски"
    }
  }

  var icon: String {
    switch self {
    case .grain: return "circle.dotted"
    case .outline: return "square.dashed"
    case .blur: return "drop.fill"
    case .colorShift: return "paintpalette"
    case .vignette: return "circle.lefthalf.filled"
    case .fogDepth: return "cloud.fog"
    case .stripes: return "line.3.horizontal"
    }
  }
}

struct EffectNode: Codable, Hashable, Identifiable {
  let id: UUID
  let type: NodeType
  var intensity: Float  // 0.0 - 1.0
  var params: [String: Float]  // Дополнительные параметры

  init(type: NodeType, intensity: Float = 1.0, params: [String: Float] = [:]) {
    self.id = UUID()
    self.type = type
    self.intensity = intensity
    self.params = params
  }

  static func defaultParams(for type: NodeType) -> [String: Float] {
    switch type {
    case .grain:
      return ["amount": 0.3, "size": 1.0]
    case .outline:
      return ["threshold": 0.5, "width": 1.0]
    case .blur:
      return ["radius": 5.0]
    case .colorShift:
      return ["hue": 0.0, "saturation": 1.0]
    case .vignette:
      return ["radius": 0.7, "softness": 0.3]
    case .fogDepth:
      return ["near": 0.3, "far": 0.8, "density": 0.5]
    case .stripes:
      return ["frequency": 20.0, "angle": 0.0, "thickness": 0.5]
    }
  }
}

struct MixConfig: Codable, Hashable {
  var effectA: String  // Имя эффекта A
  var effectB: String  // Имя эффекта B
  var ratioA: Float  // 0.0 - 1.0
  var ratioB: Float  // 0.0 - 1.0 (обычно 1 - ratioA)

  init(effectA: String, effectB: String, ratioA: Float, ratioB: Float) {
    self.effectA = effectA
    self.effectB = effectB
    self.ratioA = max(0, min(1, ratioA))
    self.ratioB = max(0, min(1, ratioB))
  }
}

struct EffectGraph: Codable, Identifiable, Hashable {
  let id: UUID
  var name: String
  var nodes: [EffectNode]
  var mix: MixConfig?
  var createdAt: Date
  var updatedAt: Date

  static let maxNodes = 8

  init(name: String, nodes: [EffectNode] = [], mix: MixConfig? = nil) {
    self.id = UUID()
    self.name = name
    self.nodes = nodes
    self.mix = mix
    self.createdAt = Date()
    self.updatedAt = Date()
  }

  var needsDepth: Bool {
    nodes.contains { $0.type.needsDepth }
  }

  var canAddNode: Bool {
    nodes.count < Self.maxNodes
  }

  mutating func addNode(_ node: EffectNode) -> Bool {
    guard canAddNode else { return false }
    nodes.append(node)
    updatedAt = Date()
    return true
  }

  @discardableResult
  mutating func removeLastNode() -> EffectNode? {
    guard !nodes.isEmpty else { return nil }
    updatedAt = Date()
    return nodes.removeLast()
  }

  mutating func clearNodes() {
    nodes.removeAll()
    updatedAt = Date()
  }
}

struct GraphUniforms {

  var nodeTypes: (Int32, Int32, Int32, Int32, Int32, Int32, Int32, Int32) = (0, 0, 0, 0, 0, 0, 0, 0)

  var nodeIntensities: (Float, Float, Float, Float, Float, Float, Float, Float) = (
    0, 0, 0, 0, 0, 0, 0, 0
  )

  var nodeCount: Int32 = 0

  var hasDepth: Float = 0.0

  init(from graph: EffectGraph, hasDepth: Bool) {
    self.nodeCount = Int32(graph.nodes.count)
    self.hasDepth = hasDepth ? 1.0 : 0.0

    for (index, node) in graph.nodes.prefix(8).enumerated() {
      let typeValue = Int32(NodeType.allCases.firstIndex(of: node.type) ?? 0) + 1
      let intensity = node.intensity

      switch index {
      case 0:
        nodeTypes.0 = typeValue
        nodeIntensities.0 = intensity
      case 1:
        nodeTypes.1 = typeValue
        nodeIntensities.1 = intensity
      case 2:
        nodeTypes.2 = typeValue
        nodeIntensities.2 = intensity
      case 3:
        nodeTypes.3 = typeValue
        nodeIntensities.3 = intensity
      case 4:
        nodeTypes.4 = typeValue
        nodeIntensities.4 = intensity
      case 5:
        nodeTypes.5 = typeValue
        nodeIntensities.5 = intensity
      case 6:
        nodeTypes.6 = typeValue
        nodeIntensities.6 = intensity
      case 7:
        nodeTypes.7 = typeValue
        nodeIntensities.7 = intensity
      default: break
      }
    }
  }
}
