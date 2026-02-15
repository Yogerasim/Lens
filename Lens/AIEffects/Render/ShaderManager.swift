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
    func nextShader() {
        let allShaders = ShaderType.allCases
        currentIndex = (currentIndex + 1) % allShaders.count
        currentShader = allShaders[currentIndex]
        print("🎨 Switched to: \(currentShader.rawValue)")
        
        // Обновляем depth политику в FramePipeline
        FramePipeline.shared.setActiveFilter(by: currentShader.fragmentFunctionName)
    }
    
    /// Переключить на предыдущий шейдер (свайп вправо)
    func previousShader() {
        let allShaders = ShaderType.allCases
        currentIndex = (currentIndex - 1 + allShaders.count) % allShaders.count
        currentShader = allShaders[currentIndex]
        print("🎨 Switched to: \(currentShader.rawValue)")
        
        // Обновляем depth политику в FramePipeline
        FramePipeline.shared.setActiveFilter(by: currentShader.fragmentFunctionName)
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
