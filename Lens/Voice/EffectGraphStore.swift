import Combine
import Foundation

@MainActor
final class EffectGraphStore: ObservableObject {

  static let shared = EffectGraphStore()

  @Published private(set) var graphs: [EffectGraph] = []

  private let fileURL: URL
  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()

  private var effectCounter: Int {
    get { UserDefaults.standard.integer(forKey: "effectGraphCounter") }
    set { UserDefaults.standard.set(newValue, forKey: "effectGraphCounter") }
  }

  private init() {

    let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    fileURL = documentsPath.appendingPathComponent("effect_graphs.json")

    encoder.outputFormatting = .prettyPrinted
    encoder.dateEncodingStrategy = .iso8601
    decoder.dateDecodingStrategy = .iso8601

    load()
  }

  func reload() {
    load()
  }

  func add(_ graph: EffectGraph) {

    var graphToAdd = graph
    graphToAdd.name = ensureUniqueName(graph.name)

    graphs.append(graphToAdd)
    save()
  }

  func update(_ graph: EffectGraph) {
    if let index = graphs.firstIndex(where: { $0.id == graph.id }) {
      graphs[index] = graph
      save()
    }
  }

  func remove(id: UUID) {
    if let index = graphs.firstIndex(where: { $0.id == id }) {
      graphs.remove(at: index)
      save()
    }
  }

  func find(byName name: String) -> EffectGraph? {
    graphs.first { $0.name.lowercased() == name.lowercased() }
  }

  func find(byId id: UUID) -> EffectGraph? {
    graphs.first { $0.id == id }
  }

  func generateUniqueName(base: String = "Effect") -> String {
    effectCounter += 1
    var name = "\(base) \(String(format: "%03d", effectCounter))"

    while graphs.contains(where: { $0.name.lowercased() == name.lowercased() }) {
      effectCounter += 1
      name = "\(base) \(String(format: "%03d", effectCounter))"
    }

    return name
  }

  func ensureUniqueName(_ name: String) -> String {
    var uniqueName = name
    var counter = 2

    while graphs.contains(where: { $0.name.lowercased() == uniqueName.lowercased() }) {
      uniqueName = "\(name) (\(counter))"
      counter += 1
    }

    return uniqueName
  }

  private func save() {
    do {
      let data = try encoder.encode(graphs)
      try data.write(to: fileURL, options: .atomic)
    } catch {
      DebugLog.error("EffectGraphStore: Failed to save - \(error.localizedDescription)")
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
      DebugLog.error("EffectGraphStore: Failed to load - \(error.localizedDescription)")
      graphs = []
    }
  }
}
