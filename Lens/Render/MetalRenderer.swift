import Metal
import QuartzCore
import CoreVideo
import CoreImage

protocol RenderEngine {
    func render(pixelBuffer: CVPixelBuffer)
}

final class MetalRenderer: RenderEngine {

    // MARK: - Public
    let metalLayer: CAMetalLayer
    
    /// Callback для получения обработанного кадра (с шейдером)
    var onRenderedFrame: ((CVPixelBuffer) -> Void)?

    // MARK: - Private
    private let device = MetalContext.shared.device
    private let queue = MetalContext.shared.commandQueue
    private let shaderManager = ShaderManager.shared
    
    // Размеры drawable для захвата
    private var drawableWidth: Int = 0
    private var drawableHeight: Int = 0
    
    // Для захвата кадров
    private var outputPixelBufferPool: CVPixelBufferPool?

    // MARK: - Init
    init(layer: CAMetalLayer) {
        self.metalLayer = layer
        self.metalLayer.device = device
        self.metalLayer.pixelFormat = .bgra8Unorm
        self.metalLayer.framebufferOnly = false
        
        print("🖼️ MetalRenderer initialized")
    }
    
    // MARK: - Setup Pixel Buffer Pool для захвата кадров
    private func setupPixelBufferPool(width: Int, height: Int) {
        // Освобождаем старый пул
        outputPixelBufferPool = nil
        
        let poolAttributes: [String: Any] = [
            kCVPixelBufferPoolMinimumBufferCountKey as String: 3
        ]
        
        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferMetalCompatibilityKey as String: true,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ]
        
        CVPixelBufferPoolCreate(
            kCFAllocatorDefault,
            poolAttributes as CFDictionary,
            pixelBufferAttributes as CFDictionary,
            &outputPixelBufferPool
        )
        
        drawableWidth = width
        drawableHeight = height
        
        // Обновляем глобальные размеры для MediaRecorder
        DeviceCapabilities.currentCameraWidth = width
        DeviceCapabilities.currentCameraHeight = height
        
        print("📐 PixelBuffer pool created: \(width)x\(height)")
    }

    // MARK: - Render
    func render(pixelBuffer: CVPixelBuffer) {
        
        guard metalLayer.drawableSize.width > 0,
              metalLayer.drawableSize.height > 0 else {
            return
        }
        
        FPSCounter.shared.tick()
        
        guard
            let drawable = metalLayer.nextDrawable(),
            let inputTexture = makeTexture(from: pixelBuffer)
        else { return }
        
        // Получаем размеры drawable (размер экрана)
        let textureWidth = drawable.texture.width
        let textureHeight = drawable.texture.height
        
        // Пересоздаём пул если размеры изменились
        if textureWidth != drawableWidth || textureHeight != drawableHeight {
            setupPixelBufferPool(width: textureWidth, height: textureHeight)
        }

        // Создаём uniforms с временем и aspect ratio
        let viewAspect = Float(metalLayer.drawableSize.width / metalLayer.drawableSize.height)
        let textureAspect = Float(inputTexture.width) / Float(inputTexture.height)

        var uniforms = ShaderUniforms(
            time: shaderManager.animationTime,
            viewAspect: viewAspect,
            textureAspect: textureAspect
        )

        guard let commandBuffer = queue.makeCommandBuffer() else { return }

        let descriptor = MTLRenderPassDescriptor()
        descriptor.colorAttachments[0].texture = drawable.texture
        descriptor.colorAttachments[0].loadAction = .clear
        descriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        descriptor.colorAttachments[0].storeAction = .store

        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else { return }

        encoder.setRenderPipelineState(shaderManager.currentPipeline)
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<ShaderUniforms>.size, index: 0)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<ShaderUniforms>.size, index: 0)
        encoder.setFragmentTexture(inputTexture, index: 0)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()

        commandBuffer.present(drawable)
        
        // Захватываем обработанный кадр если есть callback
        if onRenderedFrame != nil {
            commandBuffer.addCompletedHandler { [weak self] _ in
                self?.captureRenderedFrame(from: drawable.texture)
            }
        }
        
        commandBuffer.commit()
    }
    
    // MARK: - Capture Rendered Frame
    private func captureRenderedFrame(from texture: MTLTexture) {
        guard let pool = outputPixelBufferPool else { return }
        
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pixelBuffer)
        
        guard status == kCVReturnSuccess, let outputBuffer = pixelBuffer else {
            return
        }
        
        CVPixelBufferLockBaseAddress(outputBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(outputBuffer, []) }
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(outputBuffer) else { return }
        
        let bytesPerRow = CVPixelBufferGetBytesPerRow(outputBuffer)
        let bufferWidth = CVPixelBufferGetWidth(outputBuffer)
        let bufferHeight = CVPixelBufferGetHeight(outputBuffer)
        
        // Копируем точно по размерам буфера
        let region = MTLRegionMake2D(0, 0, bufferWidth, bufferHeight)
        texture.getBytes(baseAddress, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)
        
        // Отправляем обработанный кадр
        onRenderedFrame?(outputBuffer)
    }

    // MARK: - Helpers
    private lazy var ciContext = CIContext(mtlDevice: device)

    private func makeTexture(from pixelBuffer: CVPixelBuffer) -> MTLTexture? {

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]

        guard let texture = device.makeTexture(descriptor: descriptor) else {
            return nil
        }

        ciContext.render(
            ciImage,
            to: texture,
            commandBuffer: nil,
            bounds: CGRect(x: 0, y: 0, width: width, height: height),
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )

        return texture
    }
}
