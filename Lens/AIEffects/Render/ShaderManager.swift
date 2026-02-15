import Metal
import Foundation
import Combine
import QuartzCore

// MARK: - Shader Type Enum
enum ShaderType: String, CaseIterable {
    case comic = "Comic Style"
    case techLines = "Tech Lines"
    case acidTrip = "Acid Trip"
    case neuralPainter = "Neural Painter"
    case depthFog = "Depth Fog"
    case depthOutline = "Depth Outline"
    
    var fragmentFunctionName: String {
        switch self {
        case .comic: return "fragment_comic"
        case .techLines: return "fragment_techlines"
        case .acidTrip: return "fragment_acidtrip"
        case .neuralPainter: return "fragment_neuralpainter"
        case .depthFog: return "fragment_depthfog"
        case .depthOutline: return "fragment_depthoutline"
        }
    }
    
    var iconName: String {
        switch self {
        case .comic: return "paintbrush.fill"
        case .techLines: return "line.3.crossed.swirl.circle.fill"
        case .acidTrip: return "sparkles"
        case .neuralPainter: return "brain.head.profile"
        case .depthFog: return "cloud.fog.fill"
        case .depthOutline: return "cube.transparent"
        }
    }
}

// MARK: - Shader Uniforms (передаём время для анимации)
struct ShaderUniforms {
    var time: Float
    var viewAspect: Float
    var textureAspect: Float
    var rotation: Float      // поворот в радианах (0, π/2, π, 3π/2)
    var mirror: Float        // зеркалирование (0.0 или 1.0)
    var hasDepth: Float      // есть ли depth данные (0.0 или 1.0)
    var depthFlipX: Float    // 1.0 = flip X для depth UV, 0.0 = no flip
    var depthFlipY: Float    // 1.0 = flip Y для depth UV, 0.0 = no flip
    var intensity: Float     // сила эффекта (0.0 = passthrough, 1.0 = полный эффект)
}

// MARK: - Shader Manager
final class ShaderManager: ObservableObject {
    
    static let shared = ShaderManager()
    
    // MARK: - Published
    @Published private(set) var currentShader: ShaderType = .comic
    @Published private(set) var currentIndex: Int = 0
    
    // MARK: - Private
    private let device: MTLDevice
    private var pipelines: [ShaderType: MTLRenderPipelineState] = [:]
    private var startTime: CFTimeInterval = CACurrentMediaTime()
    
    // MARK: - Init
    private init() {
        self.device = MetalContext.shared.device
        buildAllPipelines()
    }
    
    // MARK: - Public API
    
    /// Текущий pipeline для рендера
    var currentPipeline: MTLRenderPipelineState {
        pipelines[currentShader]!
    }
    
    /// Время для анимации (секунды с момента старта)
    var animationTime: Float {
        Float(CACurrentMediaTime() - startTime)
    }
    
    /// Переключить на следующий шейдер (свайп влево)
    /// Пропускает недоступные фильтры (depth на фронталке, wrong family при записи)
    func nextShader() {
        let isFront = FramePipeline.shared.cameraManager?.isFrontCamera ?? false
        let isRecording = FramePipeline.shared.isRecording
        let recordingFamily = FramePipeline.shared.recordingFilterFamily
        
        let availableFilters = FilterLibrary.shared.availableFilters(
            isFront: isFront,
            recordingFamily: recordingFamily,
            isRecording: isRecording
        )
        
        guard !availableFilters.isEmpty else { return }
        
        // Находим текущий индекс в доступных фильтрах
        let currentFilterName = currentShader.fragmentFunctionName
        let currentAvailableIndex = availableFilters.firstIndex { $0.shaderName == currentFilterName } ?? 0
        
        // Переключаемся на следующий доступный
        let nextIndex = (currentAvailableIndex + 1) % availableFilters.count
        let nextFilter = availableFilters[nextIndex]
        
        // Обновляем текущий шейдер
        if let shaderIndex = ShaderType.allCases.firstIndex(where: { $0.fragmentFunctionName == nextFilter.shaderName }) {
            currentIndex = shaderIndex
            currentShader = ShaderType.allCases[shaderIndex]
            print("🎨 Switched to: \(currentShader.rawValue)")
            
            if isRecording, let family = recordingFamily {
                print("   🎥 Recording mode - locked to \(family.rawValue) filters")
            } else if isFront {
                print("   📱 Front camera - depth filters skipped")
            }
            
            // Обновляем depth политику в FramePipeline
            FramePipeline.shared.setActiveFilter(by: currentShader.fragmentFunctionName)
        }
    }
    
    /// Переключить на предыдущий шейдер (свайп вправо)
    /// Пропускает недоступные фильтры (depth на фронталке, wrong family при записи)
    func previousShader() {
        let isFront = FramePipeline.shared.cameraManager?.isFrontCamera ?? false
        let isRecording = FramePipeline.shared.isRecording
        let recordingFamily = FramePipeline.shared.recordingFilterFamily
        
        let availableFilters = FilterLibrary.shared.availableFilters(
            isFront: isFront,
            recordingFamily: recordingFamily,
            isRecording: isRecording
        )
        
        guard !availableFilters.isEmpty else { return }
        
        // Находим текущий индекс в доступных фильтрах
        let currentFilterName = currentShader.fragmentFunctionName
        let currentAvailableIndex = availableFilters.firstIndex { $0.shaderName == currentFilterName } ?? 0
        
        // Переключаемся на предыдущий доступный
        let prevIndex = (currentAvailableIndex - 1 + availableFilters.count) % availableFilters.count
        let prevFilter = availableFilters[prevIndex]
        
        // Обновляем текущий шейдер
        if let shaderIndex = ShaderType.allCases.firstIndex(where: { $0.fragmentFunctionName == prevFilter.shaderName }) {
            currentIndex = shaderIndex
            currentShader = ShaderType.allCases[shaderIndex]
            print("🎨 Switched to: \(currentShader.rawValue)")
            
            if isRecording, let family = recordingFamily {
                print("   🎥 Recording mode - locked to \(family.rawValue) filters")
            } else if isFront {
                print("   📱 Front camera - depth filters skipped")
            }
            
            // Обновляем depth политику в FramePipeline
            FramePipeline.shared.setActiveFilter(by: currentShader.fragmentFunctionName)
        }
    }
    
    /// Выбрать шейдер по имени fragment функции
    func selectShader(by fragmentFunctionName: String) {
        let allShaders = ShaderType.allCases
        if let index = allShaders.firstIndex(where: { $0.fragmentFunctionName == fragmentFunctionName }) {
            let previousShader = currentShader
            currentIndex = index
            currentShader = allShaders[index]
            print("🎨 ShaderManager: Switched from \(previousShader.rawValue) → \(currentShader.rawValue)")
            print("   📍 Fragment function: \(fragmentFunctionName)")
            
            // Обновляем depth политику в FramePipeline
            FramePipeline.shared.setActiveFilter(by: fragmentFunctionName)
        } else {
            print("⚠️ ShaderManager: Shader not found for function: \(fragmentFunctionName)")
            print("   📋 Available shaders: \(allShaders.map { $0.fragmentFunctionName })")
        }
    }
    
    /// Сбросить время анимации
    func resetAnimationTime() {
        startTime = CACurrentMediaTime()
    }
    
    // MARK: - Private
    
    private func buildAllPipelines() {
        guard let library = device.makeDefaultLibrary() else {
            fatalError("❌ Failed to load Metal library")
        }
        
        for shader in ShaderType.allCases {
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = library.makeFunction(name: "vertex_main")
            descriptor.fragmentFunction = library.makeFunction(name: shader.fragmentFunctionName)
            descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            
            do {
                let pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
                pipelines[shader] = pipeline
                print("✅ Built pipeline for: \(shader.rawValue)")
            } catch {
                fatalError("❌ Failed to build pipeline for \(shader.rawValue): \(error)")
            }
        }
    }
    
}
