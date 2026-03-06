import Foundation

// MARK: - Voice Commands

/// Команды, которые можно выполнить голосом
enum VoiceCommand: Equatable {
    // Существующие команды
    case selectFilter(FilterDefinition)
    case setIntensity(Float)
    case increaseIntensity
    case decreaseIntensity
    case startRecording
    case stopRecording
    case setZoom(ZoomPreset)
    case switchCamera
    case takePhoto
    
    // Команды для узлов (low-level)
    case addNode(NodeType)
    case removeLastNode
    case clearGraph
    case saveGraph(name: String?)
    
    // Новые high-level команды для рецептов
    case createEffect(EffectRecipe)
    case remixEffect(base: String, recipe: EffectRecipe)
    case applyEffect(name: String)
    
    // Команда установки эффекта с интенсивностью
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
        case (.setFilterWithIntensity(let a1, let b1), .setFilterWithIntensity(let a2, let b2)): return a1 == a2 && b1 == b2
        case (.unknown(let a), .unknown(let b)): return a == b
        default: return false
        }
    }
}

// MARK: - Voice Command Parser

/// Парсер голосовых команд (RU/EN) с расширенной грамматикой
struct VoiceCommandParser {
    
    // MARK: - Filter Synonyms (60+ вариантов)
    
    private static let filterSynonyms: [String: String] = [
        // Comic Style
        "comic": "Comic Style", "comic style": "Comic Style", "комик": "Comic Style",
        "комикс": "Comic Style", "комиксы": "Comic Style", "комикстайл": "Comic Style",
        "комик стайл": "Comic Style", "мультик": "Comic Style", "cartoon": "Comic Style",
        
        // Tech Lines
        "tech": "Tech Lines", "tech lines": "Tech Lines", "techlines": "Tech Lines",
        "тех": "Tech Lines", "техно": "Tech Lines", "технолайнс": "Tech Lines",
        "тех лайнс": "Tech Lines", "tech style": "Tech Lines",
        
        // Acid Trip
        "acid": "Acid Trip", "acid trip": "Acid Trip", "acidtrip": "Acid Trip",
        "кислота": "Acid Trip", "кислотный": "Acid Trip", "трип": "Acid Trip",
        "эсид": "Acid Trip", "асид": "Acid Trip", "психоделика": "Acid Trip",
        
        // Neural Painter
        "neural": "Neural Painter", "neural painter": "Neural Painter", "neuralpainter": "Neural Painter",
        "нейро": "Neural Painter", "нейронка": "Neural Painter", "художник": "Neural Painter",
        "нейрал": "Neural Painter", "нейрал стайл": "Neural Painter", "neural style": "Neural Painter",
        "painter": "Neural Painter", "нейропейнтер": "Neural Painter", "нейро стайл": "Neural Painter",
        
        // Depth Fog
        "depth fog": "Depth Fog", "depthfog": "Depth Fog", "fog": "Depth Fog",
        "туман": "Depth Fog", "туман глубины": "Depth Fog", "дептфог": "Depth Fog",
        "глубинный туман": "Depth Fog", "depth": "Depth Fog",
        
        // Depth Outline
        "depth outline": "Depth Outline", "depthoutline": "Depth Outline",
        "дептаутлайн": "Depth Outline", "depth lines": "Depth Outline"
    ]
    
    // MARK: - Node Type Synonyms (много вариантов)
    
    private static let nodeTypeSynonyms: [String: NodeType] = [
        // Blur
        "blur": .blur, "блюр": .blur, "размытие": .blur, "размыть": .blur,
        "размой": .blur, "блёр": .blur, "софт": .blur, "soften": .blur,
        "мягкость": .blur, "smooth": .blur, "смягчи": .blur,
        
        // Grain
        "grain": .grain, "зерно": .grain, "шум": .grain, "noise": .grain,
        "плёнка": .grain, "пленка": .grain, "песок": .grain, "грейн": .grain,
        "зернистость": .grain, "film": .grain, "гранула": .grain,
        
        // Outline
        "outline": .outline, "аутлайн": .outline,
        "грани": .outline, "обводка": .outline, "edges": .outline,
        "edge": .outline,
        
        // Stripes
        "stripes": .stripes, "полоски": .stripes, "полосы": .stripes,
        "штрихи": .stripes, "lines": .stripes, "страйпс": .stripes,
        "линейки": .stripes, "полосатый": .stripes, "stripe": .stripes,
        
        // Vignette
        "vignette": .vignette, "виньетка": .vignette, "виньет": .vignette,
        "затемнение": .vignette, "dark corners": .vignette, "darkcorners": .vignette,
        "углы": .vignette, "виньетирование": .vignette,
        
        // Color Shift
        "colorshift": .colorShift, "color shift": .colorShift, "color": .colorShift,
        "цвет": .colorShift, "оттенок": .colorShift, "hue": .colorShift,
        "сдвиг цвета": .colorShift, "кислотность": .colorShift, "колоршифт": .colorShift,
        "смена цвета": .colorShift, "перекрас": .colorShift,
        
        // Fog Depth
        "fogdepth": .fogDepth, "fog depth": .fogDepth, "туман глубины": .fogDepth,
        "глубина": .fogDepth, "дептфог": .fogDepth,
        "глубинный туман": .fogDepth
    ]
    
    // MARK: - Keywords
    
    private static let createKeywords = [
        "создай", "сделай", "сгенерируй", "create", "make", "generate",
        "построй", "собери", "новый шейдер", "new shader", "new effect",
        "создать", "сделать", "генерируй"
    ]
    
    private static let mixKeywords = [
        "замиксуй", "смешай", "mix", "blend", "микс", "миксуй",
        "объедини", "соедини", "combine", "merge", "скомбинируй"
    ]
    
    private static let addKeywords = [
        "добавь", "добавить", "add", "примени", "apply", "включи",
        "наложи", "поверх", "плюс", "plus", "with"
    ]
    
    private static let nameKeywords = [
        "назови", "name it", "call it", "имя", "name", "название",
        "сохрани как", "save as", "called"
    ]
    
    // MARK: - Main Parse
    
    static func parse(_ text: String) -> VoiceCommand {
        let normalized = normalizeText(text)
        
        
        // 1. Проверяем создание/ремикс эффекта (высший приоритет)
        if let recipeCommand = parseRecipeCommand(normalized, original: text) {
            return recipeCommand
        }
        
        // 2. Проверяем команду применения эффекта
        if let applyCommand = parseApplyEffect(normalized) {
            return applyCommand
        }
        
        // 3. Проверяем установку эффекта с интенсивностью ("комик на 30")
        if let intensityFilterCommand = parseSetFilterWithIntensity(normalized) {
            return intensityFilterCommand
        }
        
        // 4. Проверяем запись
        if let recordingCommand = parseRecording(normalized) {
            return recordingCommand
        }
        
        // 5. Проверяем интенсивность
        if let intensityCommand = parseIntensity(normalized) {
            return intensityCommand
        }
        
        // 6. Проверяем зум
        if let zoomCommand = parseZoom(normalized) {
            return zoomCommand
        }
        
        // 7. Проверяем переключение камеры
        if let cameraCommand = parseCamera(normalized) {
            return cameraCommand
        }
        
        // 8. Проверяем фото
        if let photoCommand = parsePhoto(normalized) {
            return photoCommand
        }
        
        // 9. Проверяем добавление узла (low-level)
        if let nodeCommand = parseAddNode(normalized) {
            return nodeCommand
        }
        
        // 10. Проверяем удаление/очистку
        if let editCommand = parseEditCommands(normalized) {
            return editCommand
        }
        
        // 11. Проверяем выбор built-in фильтра
        if let filterCommand = parseFilter(normalized) {
            return filterCommand
        }
        
        // Не распознано
        return .unknown(suggestions)
    }
    
    // MARK: - Text Normalization
    
    private static func normalizeText(_ text: String) -> String {
        var result = text.lowercased()
        
        // Убираем знаки препинания кроме пробелов
        result = result.replacingOccurrences(of: "[^a-zа-яё0-9\\s]", with: " ", options: .regularExpression)
        
        // Убираем лишние слова
        let noiseWords = ["ну", "так", "вот", "это", "the", "a", "an", "please", "пожалуйста", "давай"]
        for noise in noiseWords {
            result = result.replacingOccurrences(of: "\\b\(noise)\\b", with: "", options: .regularExpression)
        }
        
        // Убираем множественные пробелы
        result = result.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        
        return result.trimmingCharacters(in: .whitespaces)
    }
    
    // MARK: - Recipe Command Parser
    
    private static func parseRecipeCommand(_ text: String, original: String) -> VoiceCommand? {
        // Проверяем есть ли ключевые слова создания/микса
        let hasCreateKeyword = createKeywords.contains { text.contains($0) }
        let hasMixKeyword = mixKeywords.contains { text.contains($0) }
        
        guard hasCreateKeyword || hasMixKeyword else { return nil }
        
        var recipe = EffectRecipe()
        
        // 1. Ищем фильтры для микса используя EffectResolver
        var foundEffects: [String] = []
        let words = text.split(separator: " ").map(String.init)
        
        // Пробуем разные комбинации слов как названия эффектов
        for i in 0..<words.count {
            for length in 1...min(3, words.count - i) {
                let candidate = words[i..<i+length].joined(separator: " ")
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
        
        // 2. Ищем узлы для добавления
        var nodesToAdd: [NodeType] = []
        for (synonym, nodeType) in nodeTypeSynonyms {
            if text.contains(synonym) && addKeywords.contains(where: { text.contains($0) }) {
                if !nodesToAdd.contains(nodeType) {
                    nodesToAdd.append(nodeType)
                }
            }
        }
        recipe.nodesToAdd = nodesToAdd
        
        // 3. Ищем имя
        for nameKw in nameKeywords {
            if let range = text.range(of: nameKw) {
                let afterName = text[range.upperBound...].trimmingCharacters(in: .whitespaces)
                let nameWords = afterName.split(separator: " ").prefix(3)
                if !nameWords.isEmpty {
                    let extractedName = nameWords.joined(separator: " ")
                    let cleanName = extractedName.replacingOccurrences(of: "его|её|it|эффект|effect", with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces)
                    if !cleanName.isEmpty {
                        recipe.name = cleanName
                    }
                }
                break
            }
        }
        
        // 4. Проверяем валидность
        let signalCount = (hasCreateKeyword ? 1 : 0) + (hasMixKeyword ? 1 : 0) + foundEffects.count + nodesToAdd.count
        
        if signalCount >= 2 && recipe.isValid {
            return .createEffect(recipe)
        }
        
        return nil
    }
    
    // MARK: - Apply Effect
    
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
    
    // MARK: - Set Filter With Intensity ("комик на 30")
    
    private static func parseSetFilterWithIntensity(_ text: String) -> VoiceCommand? {
        // Паттерны для поиска: "эффект число", "эффект на число", "сделай эффект на число"
        let patterns = [
            // "комик 30", "нейро 50"
            #"([а-яa-z]+(?:\s+[а-яa-z]+)*)\s+(\d{1,3})"#,
            // "комик на 30", "нейро на 70"
            #"([а-яa-z]+(?:\s+[а-яa-z]+)*)\s+на\s+(\d{1,3})"#,
            // "сделай комик на 30"
            #"(?:сделай|делай|поставь|установи)\s+([а-яa-z]+(?:\s+[а-яa-z]+)*)\s+(?:на\s+)?(\d{1,3})"#
        ]
        
        for pattern in patterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
                let nsText = text as NSString
                
                if let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: nsText.length)) {
                    if match.numberOfRanges >= 3 {
                        let effectName = nsText.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces)
                        let percentStr = nsText.substring(with: match.range(at: 2))
                        
                        if let percent = Int(percentStr), percent >= 0, percent <= 100 {
                            // Проверяем что эффект существует
                            if EffectResolver.effectExists(name: effectName) {
                                return .setFilterWithIntensity(effectName: effectName, percent: percent)
                            }
                        }
                    }
                }
            } catch {
                // Игнорируем ошибки regex
                continue
            }
        }
        
        return nil
    }
    
    // MARK: - Add Node (low-level)
    
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
    
    // MARK: - Edit Commands
    
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
    
    // MARK: - Recording
    
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
    
    // MARK: - Intensity
    
    private static func parseIntensity(_ text: String) -> VoiceCommand? {
        let increasePatterns = ["сильнее", "больше", "increase", "more", "ярче"]
        let decreasePatterns = ["слабее", "меньше", "decrease", "less", "тише"]
        
        for pattern in increasePatterns {
            if text.contains(pattern) { return .increaseIntensity }
        }
        for pattern in decreasePatterns {
            if text.contains(pattern) { return .decreaseIntensity }
        }
        
        // Числовое значение
        let intensityPattern = #"(интенсивность|intensity|сила)\s+(\d+)"#
        if let regex = try? NSRegularExpression(pattern: intensityPattern, options: .caseInsensitive) {
            let nsText = text as NSString
            if let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: nsText.length)) {
                if match.numberOfRanges >= 3 {
                    let valueStr = nsText.substring(with: match.range(at: 2))
                    if let value = Int(valueStr) {
                        return .setIntensity(Float(min(100, max(0, value))) / 100.0)
                    }
                }
            }
        }
        
        // Процент
        let percentPattern = #"(\d{1,3})\s*(%|процент)"#
        if let match = text.range(of: percentPattern, options: .regularExpression) {
            let numberStr = text[match].filter { $0.isNumber }
            if let value = Int(numberStr), value >= 0, value <= 100 {
                return .setIntensity(Float(value) / 100.0)
            }
        }
        
        return nil
    }
    
    // MARK: - Zoom
    
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
    
    // MARK: - Camera
    
    private static func parseCamera(_ text: String) -> VoiceCommand? {
        let patterns = ["переключи камеру", "смени камеру", "switch camera", "flip camera", "фронталка", "селфи"]
        for pattern in patterns {
            if text.contains(pattern) { return .switchCamera }
        }
        return nil
    }
    
    // MARK: - Photo
    
    private static func parsePhoto(_ text: String) -> VoiceCommand? {
        let patterns = ["фото", "сфоткай", "снимок", "photo", "capture", "shot", "cheese"]
        for pattern in patterns {
            if text.contains(pattern) { return .takePhoto }
        }
        return nil
    }
    
    // MARK: - Filter
    
    private static func parseFilter(_ text: String) -> VoiceCommand? {
        // Пробуем найти эффект через EffectResolver
        let words = text.split(separator: " ").map(String.init)
        
        for i in 0..<words.count {
            for length in 1...min(3, words.count - i) {
                let candidate = words[i..<i+length].joined(separator: " ")
                
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
    
    // MARK: - Suggestions
    
    private static var suggestions: [String] {
        [
            "Создай шейдер замиксуй комик и нейро",
            "Добавь блюр",
            "Интенсивность 70%",
            "Включи миксованный",
            "Начни запись"
        ]
    }
}
