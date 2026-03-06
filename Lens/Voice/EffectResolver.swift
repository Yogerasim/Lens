import Foundation

// MARK: - Effect Source

/// Источник эффекта: встроенный фильтр или пользовательский граф
enum EffectSource {
    case builtIn(FilterDefinition)
    case custom(EffectGraph)
    
    /// Отображаемое имя эффекта
    var displayName: String {
        switch self {
        case .builtIn(let filter):
            return filter.name
        case .custom(let graph):
            return graph.name
        }
    }
    
    /// Требует ли эффект depth
    var needsDepth: Bool {
        switch self {
        case .builtIn(let filter):
            return filter.needsDepth
        case .custom(let graph):
            return graph.needsDepth
        }
    }
}

// MARK: - Effect Resolver

/// Решатель эффектов - единый механизм поиска и нормализации имён
struct EffectResolver {
    
    // MARK: - Canonical Key
    
    /// Создаёт канонический ключ для поиска эффектов
    static func canonicalKey(_ text: String) -> String {
        var result = text.lowercased()
        
        // Заменяем ё→е
        result = result.replacingOccurrences(of: "ё", with: "е")
        
        // Убираем всё кроме букв, цифр и пробелов
        result = result.replacingOccurrences(of: "[^a-zа-я0-9\\s]", with: " ", options: .regularExpression)
        
        // Убираем стоп-слова
        let stopWords = ["style", "стайл", "стиль", "shader", "шейдер", "effect", "эффект", "filter", "фильтр"]
        for stopWord in stopWords {
            result = result.replacingOccurrences(of: "\\b\(stopWord)\\b", with: "", options: .regularExpression)
        }
        
        // Сжимаем множественные пробелы и обрезаем края
        result = result.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        result = result.trimmingCharacters(in: .whitespaces)
        
        return result
    }
    
    // MARK: - Built-in Effects
    
    /// Карта канонических ключей к встроенным фильтрам (создаётся лениво)
    private static var builtInMap: [String: FilterDefinition] = {
        var map: [String: FilterDefinition] = [:]
        
        for filter in FilterLibrary.shared.filters {
            // Основное имя
            let mainKey = canonicalKey(filter.name)
            if !mainKey.isEmpty {
                map[mainKey] = filter
            }
            
            // Синонимы для каждого фильтра
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
    
    /// Получает синонимы для встроенного фильтра
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
    
    /// Ищет встроенный эффект по имени
    static func resolveBuiltInEffect(name: String) -> FilterDefinition? {
        let key = canonicalKey(name)
        guard !key.isEmpty else { return nil }
        
        // Exact match
        if let filter = builtInMap[key] {
            return filter
        }
        
        // Token overlap match
        let tokens = key.split(separator: " ").map(String.init)
        if !tokens.isEmpty {
            for (candidateKey, filter) in builtInMap {
                let candidateTokens = candidateKey.split(separator: " ").map(String.init)
                let overlap = Set(tokens).intersection(Set(candidateTokens))
                
                // Если есть общие токены и они составляют большую часть запроса
                if !overlap.isEmpty && Float(overlap.count) / Float(tokens.count) >= 0.6 {
                    return filter
                }
            }
        }
        
        return nil
    }
    
    // MARK: - Custom Effects
    
    /// Ищет пользовательский эффект по имени
    static func resolveCustomEffect(name: String) -> EffectGraph? {
        let key = canonicalKey(name)
        guard !key.isEmpty else { return nil }
        
        let store = EffectGraphStore.shared
        
        // Exact match по каноническому ключу
        for graph in store.graphs {
            if canonicalKey(graph.name) == key {
                return graph
            }
        }
        
        // Partial match
        for graph in store.graphs {
            if canonicalKey(graph.name).contains(key) || key.contains(canonicalKey(graph.name)) {
                return graph
            }
        }
        
        return nil
    }
    
    // MARK: - Universal Resolver
    
    /// Ищет любой эффект (встроенный или пользовательский)
    static func resolveAnyEffect(name: String) -> EffectSource? {
        // Сначала пробуем встроенные (приоритет)
        if let builtIn = resolveBuiltInEffect(name: name) {
            return .builtIn(builtIn)
        }
        
        // Затем пользовательские
        if let custom = resolveCustomEffect(name: name) {
            return .custom(custom)
        }
        
        return nil
    }
    
    // MARK: - Validation
    
    /// Проверяет существование эффекта
    static func effectExists(name: String) -> Bool {
        return resolveAnyEffect(name: name) != nil
    }
    
    /// Получает список всех доступных эффектов
    static func getAllAvailableEffects() -> [EffectSource] {
        var effects: [EffectSource] = []
        
        // Встроенные
        for filter in FilterLibrary.shared.filters {
            effects.append(.builtIn(filter))
        }
        
        // Пользовательские
        for graph in EffectGraphStore.shared.graphs {
            effects.append(.custom(graph))
        }
        
        return effects
    }
}