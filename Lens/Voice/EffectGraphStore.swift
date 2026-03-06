import Foundation
import Combine

/// Хранилище пользовательских графов эффектов
@MainActor
final class EffectGraphStore: ObservableObject {
    
    static let shared = EffectGraphStore()
    
    // MARK: - Published Properties
    
    @Published private(set) var graphs: [EffectGraph] = []
    
    // MARK: - Private Properties
    
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    // Счётчик для автогенерации имён
    private var effectCounter: Int {
        get { UserDefaults.standard.integer(forKey: "effectGraphCounter") }
        set { UserDefaults.standard.set(newValue, forKey: "effectGraphCounter") }
    }
    
    // MARK: - Init
    
    private init() {
        // Путь к файлу в Documents
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = documentsPath.appendingPathComponent("effect_graphs.json")
        
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        
        load()
    }
    
    // MARK: - Public Load (для вызова при старте App)
    
    func reload() {
        load()
    }
    
    // MARK: - CRUD Operations
    
    /// Добавляет новый граф
    func add(_ graph: EffectGraph) {
        // Проверяем уникальность имени
        var graphToAdd = graph
        graphToAdd.name = ensureUniqueName(graph.name)
        
        graphs.append(graphToAdd)
        save()
    }
    
    /// Обновляет существующий граф
    func update(_ graph: EffectGraph) {
        if let index = graphs.firstIndex(where: { $0.id == graph.id }) {
            graphs[index] = graph
            save()
        }
    }
    
    /// Удаляет граф по ID
    func remove(id: UUID) {
        if let index = graphs.firstIndex(where: { $0.id == id }) {
            let name = graphs[index].name
            graphs.remove(at: index)
            save()
        }
    }
    
    /// Находит граф по имени (case-insensitive)
    func find(byName name: String) -> EffectGraph? {
        graphs.first { $0.name.lowercased() == name.lowercased() }
    }
    
    /// Находит граф по ID
    func find(byId id: UUID) -> EffectGraph? {
        graphs.first { $0.id == id }
    }
    
    // MARK: - Unique Name Generation
    
    /// Генерирует уникальное имя с базовым префиксом
    func generateUniqueName(base: String = "Effect") -> String {
        effectCounter += 1
        var name = "\(base) \(String(format: "%03d", effectCounter))"
        
        // Проверяем что такого имени нет
        while graphs.contains(where: { $0.name.lowercased() == name.lowercased() }) {
            effectCounter += 1
            name = "\(base) \(String(format: "%03d", effectCounter))"
        }
        
        return name
    }
    
    /// Гарантирует уникальность имени, добавляя суффикс при необходимости
    func ensureUniqueName(_ name: String) -> String {
        var uniqueName = name
        var counter = 2
        
        while graphs.contains(where: { $0.name.lowercased() == uniqueName.lowercased() }) {
            uniqueName = "\(name) (\(counter))"
            counter += 1
        }
        
        return uniqueName
    }
    
    // MARK: - Persistence
    
    private func save() {
        do {
            let data = try encoder.encode(graphs)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("❌ EffectGraphStore: Failed to save - \(error.localizedDescription)")
        }
    }
    
    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            graphs = []
            return
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            graphs = try decoder.decode([EffectGraph].self, from: data)
        } catch {
            print("❌ EffectGraphStore: Failed to load - \(error.localizedDescription)")
            graphs = []
        }
    }
}
