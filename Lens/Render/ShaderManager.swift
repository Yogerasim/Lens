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
    
    var fragmentFunctionName: String {
        switch self {
        case .comic: return "fragment_comic"
        case .techLines: return "fragment_techlines"
        case .acidTrip: return "fragment_acidtrip"
        case .neuralPainter: return "fragment_neuralpainter"
        }
    }
    
    var iconName: String {
        switch self {
        case .comic: return "paintbrush.fill"
        case .techLines: return "line.3.crossed.swirl.circle.fill"
        case .acidTrip: return "sparkles"
        case .neuralPainter: return "brain.head.profile"
        }
    }
}

// MARK: - Shader Uniforms (передаём время для анимации)
struct ShaderUniforms {
    var time: Float
    var viewAspect: Float
    var textureAspect: Float
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
    }
    
    /// Переключить на предыдущий шейдер (свайп вправо)
    func previousShader() {
        let allShaders = ShaderType.allCases
        currentIndex = (currentIndex - 1 + allShaders.count) % allShaders.count
        currentShader = allShaders[currentIndex]
        print("🎨 Switched to: \(currentShader.rawValue)")
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
