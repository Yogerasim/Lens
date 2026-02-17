import Foundation
import Combine

@MainActor
final class FilterStore: ObservableObject {
    static let shared = FilterStore()

    @Published var active: FilterDefinition = FilterLibrary.shared.filters.first!

    private init() {}
}
