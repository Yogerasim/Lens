//
//  Filter.swift + FilterLibrary.swift
//  Lens
//
//  Created by Филипп Герасимов on 11/02/26.
//

import Foundation
import Combine

struct FilterDefinition: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let shaderName: String
    
    init(id: UUID = UUID(), name: String, shaderName: String) {
        self.id = id
        self.name = name
        self.shaderName = shaderName
    }
}

final class FilterLibrary: ObservableObject {
    static let shared = FilterLibrary()
    
    @Published var filters: [FilterDefinition] = [
        FilterDefinition(name: "Comic", shaderName: "fragment_comic"),
        FilterDefinition(name: "Tech Lines", shaderName: "fragment_techlines"),
        FilterDefinition(name: "Acid Trip", shaderName: "fragment_acidtrip"),
        FilterDefinition(name: "Neural Painter", shaderName: "fragment_neural_painter")
    ]
    
    private init() {}
}
