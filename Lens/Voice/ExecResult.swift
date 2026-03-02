import Foundation

// MARK: - Execution Status

/// Статус выполнения команды
enum ExecStatus: String, Codable {
    case success    // Команда выполнена успешно
    case error      // Ошибка выполнения
    case blocked    // Команда заблокирована (запись, камера, etc.)
    case unknown    // Команда не распознана
}

/// Результат выполнения голосовой команды
struct ExecResult {
    let status: ExecStatus
    let message: String
    let didApplyEffect: Bool
    let didCreateOrUpdateGraph: Bool
    
    // Convenience initializers
    static func success(_ message: String, appliedEffect: Bool = false, createdGraph: Bool = false) -> ExecResult {
        ExecResult(status: .success, message: message, didApplyEffect: appliedEffect, didCreateOrUpdateGraph: createdGraph)
    }
    
    static func error(_ message: String) -> ExecResult {
        ExecResult(status: .error, message: message, didApplyEffect: false, didCreateOrUpdateGraph: false)
    }
    
    static func blocked(_ message: String) -> ExecResult {
        ExecResult(status: .blocked, message: message, didApplyEffect: false, didCreateOrUpdateGraph: false)
    }
    
    static func unknown(_ message: String) -> ExecResult {
        ExecResult(status: .unknown, message: message, didApplyEffect: false, didCreateOrUpdateGraph: false)
    }
}

// MARK: - Effect Recipe

/// Рецепт создания нового эффекта
struct EffectRecipe: Codable, Hashable {
    var name: String?           // Имя эффекта (автогенерируется если nil)
    var mixA: String?           // Первый источник микса (built-in или custom)
    var mixB: String?           // Второй источник микса
    var ratioA: Float?          // Пропорция A (default 0.5)
    var ratioB: Float?          // Пропорция B (default 0.5)
    var nodesToAdd: [NodeType]  // Узлы для применения поверх микса
    
    init(name: String? = nil, mixA: String? = nil, mixB: String? = nil, 
         ratioA: Float? = nil, ratioB: Float? = nil, nodesToAdd: [NodeType] = []) {
        self.name = name
        self.mixA = mixA
        self.mixB = mixB
        self.ratioA = ratioA
        self.ratioB = ratioB
        self.nodesToAdd = nodesToAdd
    }
    
    /// Есть ли микс в рецепте
    var hasMix: Bool {
        mixA != nil && mixB != nil
    }
    
    /// Есть ли узлы в рецепте
    var hasNodes: Bool {
        !nodesToAdd.isEmpty
    }
    
    /// Валиден ли рецепт (есть хотя бы что-то)
    var isValid: Bool {
        hasMix || hasNodes
    }
}
