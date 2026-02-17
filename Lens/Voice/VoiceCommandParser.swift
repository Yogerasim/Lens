import Foundation

/// Команды, которые можно выполнить голосом
enum VoiceCommand: Equatable {
    case selectFilter(FilterDefinition)
    case setIntensity(Float)          // 0...1
    case increaseIntensity
    case decreaseIntensity
    case startRecording
    case stopRecording
    case setZoom(ZoomPreset)
    case switchCamera
    case takePhoto
    case unknown([String])            // suggestions
    
    static func == (lhs: VoiceCommand, rhs: VoiceCommand) -> Bool {
        switch (lhs, rhs) {
        case (.selectFilter(let a), .selectFilter(let b)):
            return a.id == b.id
        case (.setIntensity(let a), .setIntensity(let b)):
            return a == b
        case (.increaseIntensity, .increaseIntensity),
             (.decreaseIntensity, .decreaseIntensity),
             (.startRecording, .startRecording),
             (.stopRecording, .stopRecording),
             (.switchCamera, .switchCamera),
             (.takePhoto, .takePhoto):
            return true
        case (.setZoom(let a), .setZoom(let b)):
            return a == b
        case (.unknown(let a), .unknown(let b)):
            return a == b
        default:
            return false
        }
    }
}

/// Парсер голосовых команд (RU/EN)
struct VoiceCommandParser {
    
    // MARK: - Filter Synonyms
    
    private static let filterSynonyms: [String: String] = [
        // Comic Style
        "comic": "Comic Style",
        "комик": "Comic Style",
        "комикс": "Comic Style",
        "комиксы": "Comic Style",
        
        // Tech Lines
        "tech": "Tech Lines",
        "tech lines": "Tech Lines",
        "тех": "Tech Lines",
        "техно": "Tech Lines",
        "линии": "Tech Lines",
        
        // Acid Trip
        "acid": "Acid Trip",
        "acid trip": "Acid Trip",
        "кислота": "Acid Trip",
        "кислотный": "Acid Trip",
        "трип": "Acid Trip",
        
        // Neural Painter
        "neural": "Neural Painter",
        "neural painter": "Neural Painter",
        "нейро": "Neural Painter",
        "нейронка": "Neural Painter",
        "художник": "Neural Painter",
        "painter": "Neural Painter",
        
        // Depth Fog
        "depth fog": "Depth Fog",
        "fog": "Depth Fog",
        "туман": "Depth Fog",
        "глубина": "Depth Fog",
        
        // Depth Outline
        "depth outline": "Depth Outline",
        "outline": "Depth Outline",
        "контур": "Depth Outline",
        "контуры": "Depth Outline"
    ]
    
    // MARK: - Parse
    
    /// Парсит текст и возвращает команду
    static func parse(_ text: String) -> VoiceCommand {
        let lowercased = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 1. Проверяем команды записи
        if let recordingCommand = parseRecording(lowercased) {
            return recordingCommand
        }
        
        // 2. Проверяем команды интенсивности
        if let intensityCommand = parseIntensity(lowercased) {
            return intensityCommand
        }
        
        // 3. Проверяем команды зума
        if let zoomCommand = parseZoom(lowercased) {
            return zoomCommand
        }
        
        // 4. Проверяем переключение камеры
        if let cameraCommand = parseCamera(lowercased) {
            return cameraCommand
        }
        
        // 5. Проверяем фото
        if let photoCommand = parsePhoto(lowercased) {
            return photoCommand
        }
        
        // 6. Проверяем выбор фильтра
        if let filterCommand = parseFilter(lowercased) {
            return filterCommand
        }
        
        // 7. Не распознано
        return .unknown(suggestions)
    }
    
    // MARK: - Recording Commands
    
    private static func parseRecording(_ text: String) -> VoiceCommand? {
        let startPatterns = [
            "начни запись", "начать запись", "старт запись", "записывай",
            "start recording", "start record", "record", "начни", "запись старт"
        ]
        
        let stopPatterns = [
            "стоп", "остановить запись", "стоп запись", "хватит записывать",
            "stop recording", "stop record", "stop", "закончи запись", "конец записи"
        ]
        
        for pattern in startPatterns {
            if text.contains(pattern) {
                return .startRecording
            }
        }
        
        for pattern in stopPatterns {
            if text.contains(pattern) {
                return .stopRecording
            }
        }
        
        return nil
    }
    
    // MARK: - Intensity Commands
    
    private static func parseIntensity(_ text: String) -> VoiceCommand? {
        // Увеличить/уменьшить
        let increasePatterns = ["сильнее", "больше", "increase", "more", "усиль", "ярче"]
        let decreasePatterns = ["слабее", "меньше", "decrease", "less", "убавь", "тише"]
        
        for pattern in increasePatterns {
            if text.contains(pattern) {
                return .increaseIntensity
            }
        }
        
        for pattern in decreasePatterns {
            if text.contains(pattern) {
                return .decreaseIntensity
            }
        }
        
        // Числовое значение: "интенсивность 70%", "70 процентов", "0.7"
        
        // Паттерн: число с процентами
        let percentPattern = #"(\d{1,3})\s*(%|процент)"#
        if let match = text.range(of: percentPattern, options: .regularExpression) {
            let numberStr = text[match].filter { $0.isNumber }
            if let value = Int(numberStr), value >= 0, value <= 100 {
                return .setIntensity(Float(value) / 100.0)
            }
        }
        
        // Паттерн: "интенсивность X" или "intensity X"
        let intensityPattern = #"(интенсивность|intensity|сила)\s+(\d+)"#
        if let regex = try? NSRegularExpression(pattern: intensityPattern, options: .caseInsensitive) {
            let nsText = text as NSString
            if let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: nsText.length)) {
                if match.numberOfRanges >= 3 {
                    let valueRange = match.range(at: 2)
                    let valueStr = nsText.substring(with: valueRange)
                    if let value = Int(valueStr) {
                        let normalizedValue = min(100, max(0, value))
                        return .setIntensity(Float(normalizedValue) / 100.0)
                    }
                }
            }
        }
        
        // Паттерн: десятичное число "0.7", "0,7"
        let decimalPattern = #"0[.,](\d{1,2})"#
        if let match = text.range(of: decimalPattern, options: .regularExpression) {
            var numStr = String(text[match]).replacingOccurrences(of: ",", with: ".")
            if let value = Float(numStr), value >= 0, value <= 1 {
                return .setIntensity(value)
            }
        }
        
        return nil
    }
    
    // MARK: - Zoom Commands
    
    private static func parseZoom(_ text: String) -> VoiceCommand? {
        // Паттерн: "зум 0.5", "zoom 2", "зум 1"
        let zoomPattern = #"(зум|zoom)\s*(0[.,]5|0\.5|1|2)"#
        if let regex = try? NSRegularExpression(pattern: zoomPattern, options: .caseInsensitive) {
            let nsText = text as NSString
            if let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: nsText.length)) {
                if match.numberOfRanges >= 3 {
                    let valueRange = match.range(at: 2)
                    let valueStr = nsText.substring(with: valueRange).replacingOccurrences(of: ",", with: ".")
                    
                    switch valueStr {
                    case "0.5":
                        return .setZoom(.ultraWide)
                    case "1":
                        return .setZoom(.wide)
                    case "2":
                        return .setZoom(.telephoto)
                    default:
                        break
                    }
                }
            }
        }
        
        // Простые варианты
        if text.contains("0.5") || text.contains("0,5") || text.contains("ультра") || text.contains("ultra wide") {
            return .setZoom(.ultraWide)
        }
        
        if text.contains("телефото") || text.contains("telephoto") || text.contains("приблизь") {
            return .setZoom(.telephoto)
        }
        
        return nil
    }
    
    // MARK: - Camera Commands
    
    private static func parseCamera(_ text: String) -> VoiceCommand? {
        let patterns = [
            "переключи камеру", "смени камеру", "другая камера",
            "switch camera", "flip camera", "фронталка", "селфи", "selfie",
            "передняя камера", "задняя камера", "front camera", "back camera"
        ]
        
        for pattern in patterns {
            if text.contains(pattern) {
                return .switchCamera
            }
        }
        
        return nil
    }
    
    // MARK: - Photo Commands
    
    private static func parsePhoto(_ text: String) -> VoiceCommand? {
        let patterns = [
            "фото", "сфоткай", "снимок", "сделай фото", "сфотографируй",
            "photo", "take photo", "capture", "shot", "cheese"
        ]
        
        for pattern in patterns {
            if text.contains(pattern) {
                return .takePhoto
            }
        }
        
        return nil
    }
    
    // MARK: - Filter Commands
    
    private static func parseFilter(_ text: String) -> VoiceCommand? {
        let filters = FilterLibrary.shared.filters
        
        // 1. Проверяем синонимы
        for (synonym, filterName) in filterSynonyms {
            if text.contains(synonym) {
                if let filter = filters.first(where: { $0.name == filterName }) {
                    return .selectFilter(filter)
                }
            }
        }
        
        // 2. Проверяем частичное совпадение с именами фильтров
        for filter in filters {
            let filterNameLower = filter.name.lowercased()
            if text.contains(filterNameLower) {
                return .selectFilter(filter)
            }
            
            // Проверяем отдельные слова
            let words = filterNameLower.split(separator: " ")
            for word in words where word.count > 3 {
                if text.contains(String(word)) {
                    return .selectFilter(filter)
                }
            }
        }
        
        return nil
    }
    
    // MARK: - Suggestions
    
    private static var suggestions: [String] {
        [
            "Скажи: 'комик' для Comic Style",
            "Скажи: 'интенсивность 70%'",
            "Скажи: 'начни запись'",
            "Скажи: 'зум 2' для приближения",
            "Скажи: 'переключи камеру'"
        ]
    }
}
