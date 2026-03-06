import Foundation

enum EffectSource {
  case builtIn(FilterDefinition)
  case custom(EffectGraph)

  var displayName: String {
    switch self {
    case .builtIn(let filter):
      return filter.name
    case .custom(let graph):
      return graph.name
    }
  }

  var needsDepth: Bool {
    switch self {
    case .builtIn(let filter):
      return filter.needsDepth
    case .custom(let graph):
      return graph.needsDepth
    }
  }
}

struct EffectResolver {

  static func canonicalKey(_ text: String) -> String {
    var result = text.lowercased()

    result = result.replacingOccurrences(of: "ё", with: "е")

    result = result.replacingOccurrences(
      of: "[^a-zа-я0-9\\s]", with: " ", options: .regularExpression)

    let stopWords = [
      "style", "стайл", "стиль", "shader", "шейдер", "effect", "эффект", "filter", "фильтр",
    ]
    for stopWord in stopWords {
      result = result.replacingOccurrences(
        of: "\\b\(stopWord)\\b", with: "", options: .regularExpression)
    }

    result = result.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    result = result.trimmingCharacters(in: .whitespaces)

    return result
  }

  private static var builtInMap: [String: FilterDefinition] = {
    var map: [String: FilterDefinition] = [:]

    for filter in FilterLibrary.shared.filters {

      let mainKey = canonicalKey(filter.name)
      if !mainKey.isEmpty {
        map[mainKey] = filter
      }

      let synonyms = getSynonyms(for: filter)
      for synonym in synonyms {
        let key = canonicalKey(synonym)
        if !key.isEmpty {
          map[key] = filter
        }
      }
    }

    return map
  }()

  private static func getSynonyms(for filter: FilterDefinition) -> [String] {
    switch filter.name {
    case "Comic Style":
      return ["комик", "комикс", "мультик", "cartoon", "comic"]
    case "Tech Lines":
      return ["тех", "техно", "технолайнс", "tech", "techlines", "линии"]
    case "Acid Trip":
      return ["кислота", "кислотный", "трип", "психоделика", "acid", "эсид", "асид"]
    case "Neural Painter":
      return ["нейро", "нейронка", "художник", "нейрал", "painter", "neural"]
    case "Depth Fog":
      return ["туман", "туман глубины", "дептфог", "fog", "depth"]
    case "Depth Outline":
      return ["контур", "контуры", "обводка", "дептаутлайн", "outline"]
    default:
      return []
    }
  }

  static func resolveBuiltInEffect(name: String) -> FilterDefinition? {
    let key = canonicalKey(name)
    guard !key.isEmpty else { return nil }

    if let filter = builtInMap[key] {
      return filter
    }

    let tokens = key.split(separator: " ").map(String.init)
    if !tokens.isEmpty {
      for (candidateKey, filter) in builtInMap {
        let candidateTokens = candidateKey.split(separator: " ").map(String.init)
        let overlap = Set(tokens).intersection(Set(candidateTokens))

        if !overlap.isEmpty && Float(overlap.count) / Float(tokens.count) >= 0.6 {
          return filter
        }
      }
    }

    return nil
  }

  static func resolveCustomEffect(name: String) -> EffectGraph? {
    let key = canonicalKey(name)
    guard !key.isEmpty else { return nil }

    let store = EffectGraphStore.shared

    for graph in store.graphs {
      if canonicalKey(graph.name) == key {
        return graph
      }
    }

    for graph in store.graphs {
      if canonicalKey(graph.name).contains(key) || key.contains(canonicalKey(graph.name)) {
        return graph
      }
    }

    return nil
  }

  static func resolveAnyEffect(name: String) -> EffectSource? {

    if let builtIn = resolveBuiltInEffect(name: name) {
      return .builtIn(builtIn)
    }

    if let custom = resolveCustomEffect(name: name) {
      return .custom(custom)
    }

    return nil
  }

  static func effectExists(name: String) -> Bool {
    return resolveAnyEffect(name: name) != nil
  }

  static func getAllAvailableEffects() -> [EffectSource] {
    var effects: [EffectSource] = []

    for filter in FilterLibrary.shared.filters {
      effects.append(.builtIn(filter))
    }

    for graph in EffectGraphStore.shared.graphs {
      effects.append(.custom(graph))
    }

    return effects
  }
}
