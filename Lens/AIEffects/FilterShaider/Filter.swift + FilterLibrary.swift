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
        FilterDefinition(name: "Neural Painter", shaderName: "fragment_neuralpainter"),
        FilterDefinition(name: "Depth Fog", shaderName: "fragment_depthfog", needsDepth: true),
        FilterDefinition(name: "Depth Outline", shaderName: "fragment_depthoutline", needsDepth: true)
    ]
    
    private init() {
        let depthFilters = filters.filter { $0.needsDepth }
        print("📚 FilterLibrary: Initialized with \(filters.count) filters")
        print("   🤖 Depth filters (\(depthFilters.count)): \(depthFilters.map { $0.name }.joined(separator: ", "))")
    }
    
    /// Поиск фильтра по имени шейдера
    func filter(for shaderName: String) -> FilterDefinition? {
        return filters.first { $0.shaderName == shaderName }
    }
    
    /// ✅ FIX: Возвращает доступные фильтры в зависимости от камеры и режима записи
    /// - isFront: true если фронтальная камера активна (depth фильтры недоступны)
    /// - depthSupported: false если устройство не поддерживает depth
    /// - recordingFamily: если запись активна, блокирует переключение между семействами
    /// - isRecording: флаг активной записи
    func availableFilters(
        isFront: Bool,
        depthSupported: Bool = true,
        recordingFamily: FilterFamily? = nil,
        isRecording: Bool = false
    ) -> [FilterDefinition] {
        var available = filters
        
        // 1. На фронталке - исключаем depth фильтры ВСЕГДА
        if isFront {
            available = available.filter { !$0.needsDepth }
        }
        // 2. Если запись активна - блокируем по семейству
        else if isRecording, let family = recordingFamily {
            switch family {
            case .depth:
                available = available.filter { $0.needsDepth }
            case .nonDepth:
                available = available.filter { !$0.needsDepth }
            }
        }
        // 3. Если depth не поддерживается - исключаем depth фильтры
        else if !depthSupported {
            available = available.filter { !$0.needsDepth }
        }
        
        return available
    }
    
    /// Проверяет, доступен ли фильтр для текущей камеры и режима записи
    func isFilterAvailable(
        _ filter: FilterDefinition,
        isFront: Bool,
        recordingFamily: FilterFamily? = nil,
        isRecording: Bool = false
    ) -> Bool {
        // На фронталке depth недоступен
        if isFront && filter.needsDepth {
            return false
        }
        
        // При записи проверяем семейство
        if isRecording, let family = recordingFamily {
            let filterFamily: FilterFamily = filter.needsDepth ? .depth : .nonDepth
            if filterFamily != family {
                return false
            }
        }
        
        return true
    }
    
    /// Возвращает ближайший доступный non-depth фильтр
    func firstNonDepthFilter() -> FilterDefinition? {
        return filters.first { !$0.needsDepth }
    }
    
    /// Возвращает первый depth фильтр
    func firstDepthFilter() -> FilterDefinition? {
        return filters.first { $0.needsDepth }
    }
}
