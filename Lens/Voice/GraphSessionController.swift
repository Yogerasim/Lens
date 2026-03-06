import Foundation
import Combine

/// Контроллер сессии редактирования графа эффектов
@MainActor
final class GraphSessionController: ObservableObject {
    
    static let shared = GraphSessionController()
    
    // MARK: - Published Properties
    
    /// Текущий редактируемый граф (draft)
    @Published private(set) var draftGraph: EffectGraph
    
    /// Активен ли режим Custom Graph
    @Published private(set) var isCustomGraphActive: Bool = false
    
    /// Текущий выбранный сохранённый граф (если есть)
    @Published private(set) var selectedGraphId: UUID?
    
    // MARK: - Persistence Keys
    
    private let lastActiveEffectIdKey = "lastActiveEffectId"
    
    // MARK: - Private Properties
    
    private var store: EffectGraphStore { EffectGraphStore.shared }
    
    // MARK: - Init
    
    private init() {
        draftGraph = EffectGraph(name: "Draft")
    }
    
    // MARK: - Startup Restoration
    
    /// Восстанавливает последний активный эффект при запуске приложения
    func restoreLastActiveEffect(shaderManager: ShaderManager) {
        // Загружаем ID последнего активного эффекта
        if let idString = UserDefaults.standard.string(forKey: lastActiveEffectIdKey),
           let id = UUID(uuidString: idString),
           let graph = store.find(byId: id) {
            
            
            draftGraph = graph
            selectedGraphId = graph.id
            isCustomGraphActive = true
            
            // Активируем Custom Graph shader
            if let customFilter = FilterLibrary.shared.filters.first(where: { $0.shaderName == "fragment_universalgraph" }) {
                shaderManager.selectShader(by: customFilter.shaderName)
            }
        } else {
            // Выбираем дефолтный built-in фильтр
            if let firstFilter = FilterLibrary.shared.filters.first(where: { $0.shaderName != "fragment_universalgraph" }) {
                shaderManager.selectShader(by: firstFilter.shaderName)
            }
        }
    }
    
    /// Сохраняет ID текущего активного эффекта
    private func saveLastActiveEffect() {
        if let id = selectedGraphId {
            UserDefaults.standard.set(id.uuidString, forKey: lastActiveEffectIdKey)
        } else {
            UserDefaults.standard.removeObject(forKey: lastActiveEffectIdKey)
        }
    }
    
    // MARK: - Node Operations
    
    /// Добавляет узел в draft граф
    @discardableResult
    func addNode(_ type: NodeType, intensity: Float = 1.0) -> (success: Bool, message: String) {
        guard draftGraph.canAddNode else {
            return (false, "❌ Достигнут лимит: макс. \(EffectGraph.maxNodes) узлов")
        }
        
        let node = EffectNode(
            type: type,
            intensity: intensity,
            params: EffectNode.defaultParams(for: type)
        )
        
        _ = draftGraph.addNode(node)
        isCustomGraphActive = true
        
        return (true, "✅ Добавлено: \(type.displayName)")
    }
    
    /// Удаляет последний узел
    @discardableResult
    func removeLastNode() -> (success: Bool, message: String) {
        guard let removed = draftGraph.removeLastNode() else {
            return (false, "⚠️ Нет узлов для удаления")
        }
        
        if draftGraph.nodes.isEmpty {
            isCustomGraphActive = false
        }
        
        return (true, "✅ Удалено: \(removed.type.displayName)")
    }
    
    /// Очищает все узлы
    @discardableResult
    func clearGraph() -> (success: Bool, message: String) {
        draftGraph.clearNodes()
        isCustomGraphActive = false
        selectedGraphId = nil
        saveLastActiveEffect()
        
        return (true, "✅ Граф очищен")
    }
    
    /// Сохраняет draft в библиотеку
    @discardableResult
    func saveGraph(name: String?) -> (success: Bool, message: String) {
        let graphName = (name?.isEmpty == false) ? name! : store.generateUniqueName(base: "Effect")
        
        guard !draftGraph.nodes.isEmpty || draftGraph.mix != nil else {
            return (false, "⚠️ Добавьте хотя бы один узел или микс перед сохранением")
        }
        
        var graphToSave = draftGraph
        graphToSave.name = graphName
        
        store.add(graphToSave)
        selectedGraphId = graphToSave.id
        saveLastActiveEffect()
        
        return (true, "✅ Сохранено: \(graphName)")
    }
    
    /// Загружает граф из библиотеки по имени
    @discardableResult
    func selectGraph(name: String) -> (success: Bool, message: String) {
        guard let graph = store.find(byName: name) else {
            return (false, "❌ Эффект '\(name)' не найден")
        }
        
        return selectGraph(graph)
    }
    
    /// Загружает граф по объекту
    @discardableResult
    func selectGraph(_ graph: EffectGraph) -> (success: Bool, message: String) {
        draftGraph = graph
        selectedGraphId = graph.id
        isCustomGraphActive = true
        saveLastActiveEffect()
        
        return (true, "✅ Загружено: \(graph.name)")
    }
    
    /// Создаёт новый пустой draft
    func newDraft() {
        draftGraph = EffectGraph(name: "Draft")
        selectedGraphId = nil
        isCustomGraphActive = false
    }
    
    // MARK: - Mix Operations
    
    /// Устанавливает микс двух эффектов
    @discardableResult
    func setMix(effectA: String, effectB: String, ratioA: Float, ratioB: Float) -> (success: Bool, message: String) {
        // Используем EffectResolver для проверки существования эффектов
        guard EffectResolver.effectExists(name: effectA) else {
            return (false, "❌ Эффект '\(effectA)' не найден")
        }
        guard EffectResolver.effectExists(name: effectB) else {
            return (false, "❌ Эффект '\(effectB)' не найден")
        }
        
        draftGraph.mix = MixConfig(effectA: effectA, effectB: effectB, ratioA: ratioA, ratioB: ratioB)
        
        let percentA = Int(ratioA * 100)
        let percentB = Int(ratioB * 100)
        return (true, "✅ Микс: \(effectA) \(percentA)% + \(effectB) \(percentB)%")
    }
    
    // MARK: - Graph Uniforms
    
    /// Получает uniforms для текущего draft графа
    func getGraphUniforms(hasDepth: Bool) -> GraphUniforms {
        return GraphUniforms(from: draftGraph, hasDepth: hasDepth)
    }
}
