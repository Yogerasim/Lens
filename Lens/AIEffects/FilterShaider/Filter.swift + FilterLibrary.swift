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
    let supportsIntensity: Bool
    
    init(id: UUID = UUID(), name: String, shaderName: String, needsDepth: Bool = false, supportsIntensity: Bool = true) {
        self.id = id
        self.name = name
        self.shaderName = shaderName
        self.needsDepth = needsDepth
        self.supportsIntensity = supportsIntensity
    }
}

final class FilterLibrary: ObservableObject {
    static let shared = FilterLibrary()

    @Published private(set) var filters: [FilterDefinition] = []

    private init() {
        filters = ShaderRegistry.all.map {
            FilterDefinition(
                name: $0.displayName,
                shaderName: $0.fragment,
                needsDepth: $0.needsDepth,
                supportsIntensity: $0.supportsIntensity
            )
        }
    }

    func filter(for shaderName: String) -> FilterDefinition? {
        filters.first { $0.shaderName == shaderName }
    }

    func firstNonDepthFilter() -> FilterDefinition? {
        filters.first { !$0.needsDepth }
    }

    func firstDepthFilter() -> FilterDefinition? {
        filters.first { $0.needsDepth }
    }

    func availableFilters(
        isFront: Bool,
        depthSupported: Bool = true,
        recordingFamily: FilterFamily? = nil,
        isRecording: Bool = false
    ) -> [FilterDefinition] {

        var available = filters

        if isFront {
            available = available.filter { !$0.needsDepth }
        } else if isRecording, let family = recordingFamily {
            switch family {
            case .depth: available = available.filter { $0.needsDepth }
            case .nonDepth: available = available.filter { !$0.needsDepth }
            }
        } else if !depthSupported {
            available = available.filter { !$0.needsDepth }
        }

        return available
    }
}
