import Foundation

enum VoiceCommand: Equatable {

  case selectFilter(FilterDefinition)
  case setIntensity(Float)
  case increaseIntensity
  case decreaseIntensity
  case startRecording
  case stopRecording
  case setZoom(ZoomPreset)
  case switchCamera
  case takePhoto

  case addNode(NodeType)
  case removeLastNode
  case clearGraph
  case saveGraph(name: String?)

  case createEffect(EffectRecipe)
  case remixEffect(base: String, recipe: EffectRecipe)
  case applyEffect(name: String)

  case setFilterWithIntensity(effectName: String, percent: Int)

  case unknown([String])

  static func == (lhs: VoiceCommand, rhs: VoiceCommand) -> Bool {
    switch (lhs, rhs) {
    case (.selectFilter(let a), .selectFilter(let b)): return a.id == b.id
    case (.setIntensity(let a), .setIntensity(let b)): return a == b
    case (.increaseIntensity, .increaseIntensity): return true
    case (.decreaseIntensity, .decreaseIntensity): return true
    case (.startRecording, .startRecording): return true
    case (.stopRecording, .stopRecording): return true
    case (.switchCamera, .switchCamera): return true
    case (.takePhoto, .takePhoto): return true
    case (.setZoom(let a), .setZoom(let b)): return a == b
    case (.addNode(let a), .addNode(let b)): return a == b
    case (.removeLastNode, .removeLastNode): return true
    case (.clearGraph, .clearGraph): return true
    case (.saveGraph(let a), .saveGraph(let b)): return a == b
    case (.createEffect(let a), .createEffect(let b)): return a == b
    case (.remixEffect(let a1, let b1), .remixEffect(let a2, let b2)): return a1 == a2 && b1 == b2
    case (.applyEffect(let a), .applyEffect(let b)): return a == b
    case (.setFilterWithIntensity(let a1, let b1), .setFilterWithIntensity(let a2, let b2)):
      return a1 == a2 && b1 == b2
    case (.unknown(let a), .unknown(let b)): return a == b
    default: return false
    }
  }
}

struct VoiceCommandParser {

  private static let filterSynonyms: [String: String] = [

    "comic": "Comic Style", "comic style": "Comic Style", "комик": "Comic Style",
    "комикс": "Comic Style", "комиксы": "Comic Style", "комикстайл": "Comic Style",
    "комик стайл": "Comic Style", "мультик": "Comic Style", "cartoon": "Comic Style",

    "tech": "Tech Lines", "tech lines": "Tech Lines", "techlines": "Tech Lines",
    "тех": "Tech Lines", "техно": "Tech Lines", "технолайнс": "Tech Lines",
    "тех лайнс": "Tech Lines", "tech style": "Tech Lines",

    "acid": "Acid Trip", "acid trip": "Acid Trip", "acidtrip": "Acid Trip",
    "кислота": "Acid Trip", "кислотный": "Acid Trip", "трип": "Acid Trip",
    "эсид": "Acid Trip", "асид": "Acid Trip", "психоделика": "Acid Trip",

    "neural": "Neural Painter", "neural painter": "Neural Painter",
    "neuralpainter": "Neural Painter",
    "нейро": "Neural Painter", "нейронка": "Neural Painter", "художник": "Neural Painter",
    "нейрал": "Neural Painter", "нейрал стайл": "Neural Painter", "neural style": "Neural Painter",
    "painter": "Neural Painter", "нейропейнтер": "Neural Painter", "нейро стайл": "Neural Painter",

    "depth fog": "Depth Fog", "depthfog": "Depth Fog", "fog": "Depth Fog",
    "туман": "Depth Fog", "туман глубины": "Depth Fog", "дептфог": "Depth Fog",
    "глубинный туман": "Depth Fog", "depth": "Depth Fog",

    "depth outline": "Depth Outline", "depthoutline": "Depth Outline",
    "дептаутлайн": "Depth Outline", "depth lines": "Depth Outline",
  ]

  private static let nodeTypeSynonyms: [String: NodeType] = [

    "blur": .blur, "блюр": .blur, "размытие": .blur, "размыть": .blur,
    "размой": .blur, "блёр": .blur, "софт": .blur, "soften": .blur,
    "мягкость": .blur, "smooth": .blur, "смягчи": .blur,

    "grain": .grain, "зерно": .grain, "шум": .grain, "noise": .grain,
    "плёнка": .grain, "пленка": .grain, "песок": .grain, "грейн": .grain,
    "зернистость": .grain, "film": .grain, "гранула": .grain,

    "outline": .outline, "аутлайн": .outline,
    "грани": .outline, "обводка": .outline, "edges": .outline,
    "edge": .outline,

    "stripes": .stripes, "полоски": .stripes, "полосы": .stripes,
    "штрихи": .stripes, "lines": .stripes, "страйпс": .stripes,
    "линейки": .stripes, "полосатый": .stripes, "stripe": .stripes,

    "vignette": .vignette, "виньетка": .vignette, "виньет": .vignette,
    "затемнение": .vignette, "dark corners": .vignette, "darkcorners": .vignette,
    "углы": .vignette, "виньетирование": .vignette,

    "colorshift": .colorShift, "color shift": .colorShift, "color": .colorShift,
    "цвет": .colorShift, "оттенок": .colorShift, "hue": .colorShift,
    "сдвиг цвета": .colorShift, "кислотность": .colorShift, "колоршифт": .colorShift,
    "смена цвета": .colorShift, "перекрас": .colorShift,

    "fogdepth": .fogDepth, "fog depth": .fogDepth, "туман глубины": .fogDepth,
    "глубина": .fogDepth, "дептфог": .fogDepth,
    "глубинный туман": .fogDepth,
  ]

  private static let createKeywords = [
    "создай", "сделай", "сгенерируй", "create", "make", "generate",
    "построй", "собери", "новый шейдер", "new shader", "new effect",
    "создать", "сделать", "генерируй",
  ]

  private static let mixKeywords = [
    "замиксуй", "смешай", "mix", "blend", "микс", "миксуй",
    "объедини", "соедини", "combine", "merge", "скомбинируй",
  ]

  private static let addKeywords = [
    "добавь", "добавить", "add", "примени", "apply", "включи",
    "наложи", "поверх", "плюс", "plus", "with",
  ]

  private static let nameKeywords = [
    "назови", "name it", "call it", "имя", "name", "название",
    "сохрани как", "save as", "called",
  ]

  static func parse(_ text: String) -> VoiceCommand {
    let normalized = normalizeText(text)

    if let recipeCommand = parseRecipeCommand(normalized, original: text) {
      return recipeCommand
    }

    if let applyCommand = parseApplyEffect(normalized) {
      return applyCommand
    }

    if let intensityFilterCommand = parseSetFilterWithIntensity(normalized) {
      return intensityFilterCommand
    }

    if let recordingCommand = parseRecording(normalized) {
      return recordingCommand
    }

    if let intensityCommand = parseIntensity(normalized) {
      return intensityCommand
    }

    if let zoomCommand = parseZoom(normalized) {
      return zoomCommand
    }

    if let cameraCommand = parseCamera(normalized) {
      return cameraCommand
    }

    if let photoCommand = parsePhoto(normalized) {
      return photoCommand
    }

    if let nodeCommand = parseAddNode(normalized) {
      return nodeCommand
    }

    if let editCommand = parseEditCommands(normalized) {
      return editCommand
    }

    if let filterCommand = parseFilter(normalized) {
      return filterCommand
    }

    return .unknown(suggestions)
  }

  private static func normalizeText(_ text: String) -> String {
    var result = text.lowercased()

    result = result.replacingOccurrences(
      of: "[^a-zа-яё0-9\\s]", with: " ", options: .regularExpression)

    let noiseWords = ["ну", "так", "вот", "это", "the", "a", "an", "please", "пожалуйста", "давай"]
    for noise in noiseWords {
      result = result.replacingOccurrences(
        of: "\\b\(noise)\\b", with: "", options: .regularExpression)
    }

    result = result.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

    return result.trimmingCharacters(in: .whitespaces)
  }

  private static func parseRecipeCommand(_ text: String, original: String) -> VoiceCommand? {

    let hasCreateKeyword = createKeywords.contains { text.contains($0) }
    let hasMixKeyword = mixKeywords.contains { text.contains($0) }

    guard hasCreateKeyword || hasMixKeyword else { return nil }

    var recipe = EffectRecipe()

    var foundEffects: [String] = []
    let words = text.split(separator: " ").map(String.init)

    for i in 0..<words.count {
      for length in 1...min(3, words.count - i) {
        let candidate = words[i..<i + length].joined(separator: " ")
        if let source = EffectResolver.resolveAnyEffect(name: candidate) {
          let effectName = source.displayName
          if !foundEffects.contains(effectName) {
            foundEffects.append(effectName)
          }
        }
      }
    }

    if foundEffects.count >= 2 {
      recipe.mixA = foundEffects[0]
      recipe.mixB = foundEffects[1]
    } else if foundEffects.count == 1 && hasMixKeyword {
      recipe.mixA = foundEffects[0]
    }

    var nodesToAdd: [NodeType] = []
    for (synonym, nodeType) in nodeTypeSynonyms {
      if text.contains(synonym) && addKeywords.contains(where: { text.contains($0) }) {
        if !nodesToAdd.contains(nodeType) {
          nodesToAdd.append(nodeType)
        }
      }
    }
    recipe.nodesToAdd = nodesToAdd

    for nameKw in nameKeywords {
      if let range = text.range(of: nameKw) {
        let afterName = text[range.upperBound...].trimmingCharacters(in: .whitespaces)
        let nameWords = afterName.split(separator: " ").prefix(3)
        if !nameWords.isEmpty {
          let extractedName = nameWords.joined(separator: " ")
          let cleanName = extractedName.replacingOccurrences(
            of: "его|её|it|эффект|effect", with: "", options: .regularExpression
          ).trimmingCharacters(in: .whitespaces)
          if !cleanName.isEmpty {
            recipe.name = cleanName
          }
        }
        break
      }
    }

    let signalCount =
      (hasCreateKeyword ? 1 : 0) + (hasMixKeyword ? 1 : 0) + foundEffects.count + nodesToAdd.count

    if signalCount >= 2 && recipe.isValid {
      return .createEffect(recipe)
    }

    return nil
  }

  private static func parseApplyEffect(_ text: String) -> VoiceCommand? {
    let applyKeywords = ["включи", "примени", "выбери", "apply", "select", "use", "загрузи"]

    for keyword in applyKeywords {
      if text.contains(keyword) {
        for graph in EffectGraphStore.shared.graphs {
          if text.contains(graph.name.lowercased()) {
            return .applyEffect(name: graph.name)
          }
        }
      }
    }

    return nil
  }

  private static func parseSetFilterWithIntensity(_ text: String) -> VoiceCommand? {

    let patterns = [

      #"([а-яa-z]+(?:\s+[а-яa-z]+)*)\s+(\d{1,3})"#,

      #"([а-яa-z]+(?:\s+[а-яa-z]+)*)\s+на\s+(\d{1,3})"#,

      #"(?:сделай|делай|поставь|установи)\s+([а-яa-z]+(?:\s+[а-яa-z]+)*)\s+(?:на\s+)?(\d{1,3})"#,
    ]

    for pattern in patterns {
      do {
        let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        let nsText = text as NSString

        if let match = regex.firstMatch(
          in: text, options: [], range: NSRange(location: 0, length: nsText.length))
        {
          if match.numberOfRanges >= 3 {
            let effectName = nsText.substring(with: match.range(at: 1)).trimmingCharacters(
              in: .whitespaces)
            let percentStr = nsText.substring(with: match.range(at: 2))

            if let percent = Int(percentStr), percent >= 0, percent <= 100 {

              if EffectResolver.effectExists(name: effectName) {
                return .setFilterWithIntensity(effectName: effectName, percent: percent)
              }
            }
          }
        }
      } catch {

        continue
      }
    }

    return nil
  }

  private static func parseAddNode(_ text: String) -> VoiceCommand? {
    let hasAddKeyword = addKeywords.contains { text.contains($0) }
    guard hasAddKeyword else { return nil }

    for (synonym, nodeType) in nodeTypeSynonyms {
      if text.contains(synonym) {
        return .addNode(nodeType)
      }
    }

    return nil
  }

  private static func parseEditCommands(_ text: String) -> VoiceCommand? {
    let removePatterns = ["удали", "убери", "undo", "отмени", "remove", "delete"]
    let clearPatterns = ["очисти", "clear", "сброс", "reset"]
    let savePatterns = ["сохрани", "save", "запомни"]

    for pattern in removePatterns {
      if text.contains(pattern) { return .removeLastNode }
    }

    for pattern in clearPatterns {
      if text.contains(pattern) { return .clearGraph }
    }

    for pattern in savePatterns {
      if text.contains(pattern) {
        var name: String? = nil
        for nameKw in nameKeywords {
          if let range = text.range(of: nameKw) {
            let afterName = text[range.upperBound...].trimmingCharacters(in: .whitespaces)
            let nameWords = afterName.split(separator: " ").prefix(3)
            if !nameWords.isEmpty {
              name = nameWords.joined(separator: " ")
            }
            break
          }
        }
        return .saveGraph(name: name)
      }
    }

    return nil
  }

  private static func parseRecording(_ text: String) -> VoiceCommand? {
    let stopPatterns = ["стоп", "stop", "остановить", "хватит", "конец"]
    let startPatterns = ["start", "начни", "запись", "record", "записывай"]

    for pattern in stopPatterns {
      if text.contains(pattern) { return .stopRecording }
    }

    for pattern in startPatterns {
      if text.contains(pattern) { return .startRecording }
    }

    return nil
  }

  private static func parseIntensity(_ text: String) -> VoiceCommand? {
    let increasePatterns = ["сильнее", "больше", "increase", "more", "ярче"]
    let decreasePatterns = ["слабее", "меньше", "decrease", "less", "тише"]

    for pattern in increasePatterns {
      if text.contains(pattern) { return .increaseIntensity }
    }
    for pattern in decreasePatterns {
      if text.contains(pattern) { return .decreaseIntensity }
    }

    let intensityPattern = #"(интенсивность|intensity|сила)\s+(\d+)"#
    if let regex = try? NSRegularExpression(pattern: intensityPattern, options: .caseInsensitive) {
      let nsText = text as NSString
      if let match = regex.firstMatch(
        in: text, options: [], range: NSRange(location: 0, length: nsText.length))
      {
        if match.numberOfRanges >= 3 {
          let valueStr = nsText.substring(with: match.range(at: 2))
          if let value = Int(valueStr) {
            return .setIntensity(Float(min(100, max(0, value))) / 100.0)
          }
        }
      }
    }

    let percentPattern = #"(\d{1,3})\s*(%|процент)"#
    if let match = text.range(of: percentPattern, options: .regularExpression) {
      let numberStr = text[match].filter { $0.isNumber }
      if let value = Int(numberStr), value >= 0, value <= 100 {
        return .setIntensity(Float(value) / 100.0)
      }
    }

    return nil
  }

  private static func parseZoom(_ text: String) -> VoiceCommand? {
    if text.contains("0 5") || text.contains("0.5") || text.contains("ультра") {
      return .setZoom(.ultraWide)
    }
    if text.contains("зум 2") || text.contains("zoom 2") || text.contains("телефото") {
      return .setZoom(.telephoto)
    }
    if text.contains("зум 1") || text.contains("zoom 1") {
      return .setZoom(.wide)
    }
    return nil
  }

  private static func parseCamera(_ text: String) -> VoiceCommand? {
    let patterns = [
      "переключи камеру", "смени камеру", "switch camera", "flip camera", "фронталка", "селфи",
    ]
    for pattern in patterns {
      if text.contains(pattern) { return .switchCamera }
    }
    return nil
  }

  private static func parsePhoto(_ text: String) -> VoiceCommand? {
    let patterns = ["фото", "сфоткай", "снимок", "photo", "capture", "shot", "cheese"]
    for pattern in patterns {
      if text.contains(pattern) { return .takePhoto }
    }
    return nil
  }

  private static func parseFilter(_ text: String) -> VoiceCommand? {

    let words = text.split(separator: " ").map(String.init)

    for i in 0..<words.count {
      for length in 1...min(3, words.count - i) {
        let candidate = words[i..<i + length].joined(separator: " ")

        if let source = EffectResolver.resolveAnyEffect(name: candidate) {
          switch source {
          case .builtIn(let filter):
            return .selectFilter(filter)
          case .custom(let graph):
            return .applyEffect(name: graph.name)
          }
        }
      }
    }

    return nil
  }

  private static var suggestions: [String] {
    [
      "Создай шейдер замиксуй комик и нейро",
      "Добавь блюр",
      "Интенсивность 70%",
      "Включи миксованный",
      "Начни запись",
    ]
  }
}
