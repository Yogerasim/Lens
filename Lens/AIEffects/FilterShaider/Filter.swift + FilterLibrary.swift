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
    let needsDepth: Bool
    
    init(id: UUID = UUID(), name: String, shaderName: String, needsDepth: Bool = false) {
        self.id = id
        self.name = name
        self.shaderName = shaderName
        self.needsDepth = needsDepth
    }
}

final class FilterLibrary: ObservableObject {
    static let shared = FilterLibrary()
    
    @Published var filters: [FilterDefinition] = [
        FilterDefinition(name: "Comic", shaderName: "fragment_comic"),
        FilterDefinition(name: "Tech Lines", shaderName: "fragment_techlines"),
        FilterDefinition(name: "Acid Trip", shaderName: "fragment_acidtrip"),
        FilterDefinition(name: "Neural Painter", shaderName: "fragment_neural_painter"),
        FilterDefinition(name: "Depth Fog", shaderName: "fragment_depthfog", needsDepth: true),
        FilterDefinition(name: "Depth Outline", shaderName: "fragment_depthoutline", needsDepth: true)
    ]
    
    private init() {
        print("📚 FilterLibrary: Initialized with \(filters.count) filters")
    }
}
