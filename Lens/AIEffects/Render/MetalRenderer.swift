import Metal
import QuartzCore
import CoreVideo
import CoreImage
internal import AVFoundation

protocol RenderEngine {
    
    func render(packet: FramePacket, activeFilter: FilterDefinition?)
    
}

final class MetalRenderer: RenderEngine {

    // MARK: - Public
    let metalLayer: CAMetalLayer
    
    /// Callback для получения обработанного кадра (с шейдером)
    /// Параметры: pixelBuffer, hasDepth (стабильный флаг), depthAvailable (есть ли depth в этом кадре)
    var onRenderedFrame: ((CVPixelBuffer, Bool, Bool) -> Void)?
    
    /// Ссылка на CameraManager для получения информации о камере
    weak var cameraManager: CameraManager?

    // MARK: - Private
    private let device = MetalContext.shared.device
    private let queue = MetalContext.shared.commandQueue
    private let shaderManager = ShaderManager.shared
    
    // Размеры drawable для захвата
    private var drawableWidth: Int = 0
    private var drawableHeight: Int = 0
    
    // Для захвата кадров
    private var outputPixelBufferPool: CVPixelBufferPool?
    
    // Hold-last depth texture для стабильной записи
    private var lastDepthTexture: MTLTexture?
    
    // Стабильный hasDepth флаг (не дёргается во время записи)
    private var stableHasDepth: Bool = false
    
    // Fallback depth текстура (1x1 черная) для шейдеров когда depth недоступен
    private lazy var placeholderDepthTexture: MTLTexture = {
        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .r32Float,
            width: 1,
            height: 1,
            mipmapped: false
        )
        desc.usage = [.shaderRead]
        let tex = device.makeTexture(descriptor: desc)!
        // Заполняем нулями (максимальная "дальность")
        var zero: Float = 0.0
        tex.replace(region: MTLRegionMake2D(0, 0, 1, 1), mipmapLevel: 0, withBytes: &zero, bytesPerRow: 4)
        return tex
    }()
    
    // Для троттлинга диагностических принтов
    private var lastDiagnosticPrintTime: CFTimeInterval = 0
    private let diagnosticPrintInterval: CFTimeInterval = 2.0

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
    func render(packet: FramePacket, activeFilter: FilterDefinition?) {
        let pixelBuffer = packet.pixelBuffer
        let depthPixelBuffer = packet.depthPixelBuffer
        
        guard metalLayer.drawableSize.width > 0,
              metalLayer.drawableSize.height > 0 else {
            return
        }
        
        FPSCounter.shared.tick()
        
        guard
            let drawable = metalLayer.nextDrawable(),
            let inputTexture = makeTexture(from: pixelBuffer)
        else { return }
        
        // Создаём depth текстуру или используем placeholder/hold-last
        let depthTexture: MTLTexture
        let hasDepth: Float
        let depthAvailable: Bool
        
        if let depthBuffer = depthPixelBuffer,
           let dTex = makeDepthTexture(from: depthBuffer) {
            // Есть свежий depth
            depthTexture = dTex
            lastDepthTexture = dTex  // Сохраняем для hold-last
            hasDepth = 1.0
            depthAvailable = true
        } else if let lastTex = lastDepthTexture, cameraManager?.isDepthEnabled == true {
            // ✅ FIX: Используем hold-last depth texture (не дёргаем hasDepth)
            depthTexture = lastTex
            hasDepth = 1.0
            depthAvailable = false  // Свежий depth не пришёл, используем предыдущий
        } else {
            depthTexture = placeholderDepthTexture
            hasDepth = 0.0
            depthAvailable = false
        }
        
        // Получаем размеры drawable (размер экрана)
        let textureWidth = drawable.texture.width
        let textureHeight = drawable.texture.height
        
        // Пересоздаём пул если размеры изменились
        if textureWidth != drawableWidth || textureHeight != drawableHeight {
            setupPixelBufferPool(width: textureWidth, height: textureHeight)
        }

        // Создаём uniforms с правильной ориентацией
        let viewAspect = Float(metalLayer.drawableSize.width / metalLayer.drawableSize.height)
        let inputWidth = Float(inputTexture.width)
        let inputHeight = Float(inputTexture.height)
        let textureAspect = inputWidth / inputHeight
        
        // ✅ FIX: Автоматическое определение rotation по размерам буфера
        // Если буфер уже portrait (w < h) - не вращаем
        // Если буфер landscape (w > h) - вращаем на 90°
        let bufferWidth = CVPixelBufferGetWidth(pixelBuffer)
        let bufferHeight = CVPixelBufferGetHeight(pixelBuffer)
        
        let rotation: Float
        if bufferWidth < bufferHeight {
            // Буфер уже portrait (например LiDAR 1080x1920 или iOS 17+ с videoRotationAngle=90) - не вращаем
            rotation = 0.0
        } else {
            // Буфер landscape (обычная камера 3840x2160) - вращаем на 90°
            rotation = Float.pi / 2.0
        }
        
        // ✅ FIX: Mirror теперь ТОЛЬКО через AVCaptureConnection, не в шейдере
        // Это исключает двойное зеркалирование
        let mirror: Float = 0.0
        
        // ✅ FIX: Depth UV коррекция для LiDAR режима
        // LiDAR depth map имеет другую ориентацию чем RGB - нужен flip
        let isLiDARMode = cameraManager?.isDepthEnabled ?? false
        let depthFlipX: Float = 0.0  // Обычно X не нужно флипать
        let depthFlipY: Float = isLiDARMode ? 1.0 : 0.0  // Флипаем Y в LiDAR режиме
        
        // ✅ Effect intensity (smoothed, 0.0 = passthrough, 1.0 = full effect)
        let intensity = FramePipeline.shared.effectIntensityForMetal

        var uniforms = ShaderUniforms(
            time: shaderManager.animationTime,
            viewAspect: viewAspect,
            textureAspect: textureAspect,
            rotation: rotation,
            mirror: mirror,
            hasDepth: hasDepth,
            depthFlipX: depthFlipX,
            depthFlipY: depthFlipY,
            intensity: intensity
        )
        
        // Диагностические принты с троттлингом (раз в 2 секунды)
        let now = CACurrentMediaTime()
        if now - lastDiagnosticPrintTime > diagnosticPrintInterval {
            lastDiagnosticPrintTime = now
            
            // Логируем автоматический rotation
            print("🧭 AutoRotation: w=\(bufferWidth) h=\(bufferHeight) rotation=\(rotation == 0 ? "0 (portrait)" : "π/2 (landscape)") hasDepth=\(hasDepth)")
            
            // Логируем depth flip флаги
            print("🧪 DepthFlip: depthFlipX=\(depthFlipX) depthFlipY=\(depthFlipY) isLiDARMode=\(isLiDARMode)")
            
            // Логируем intensity
            print("🎚️ Effect intensity: \(String(format: "%.2f", intensity))")
            
            // Логируем размеры depth если есть
            if let depthBuffer = depthPixelBuffer {
                let depthW = CVPixelBufferGetWidth(depthBuffer)
                let depthH = CVPixelBufferGetHeight(depthBuffer)
                print("📊 DepthBuffer size: \(depthW)x\(depthH)")
            }
            
            let deviceType = cameraManager?.currentInput?.device.deviceType.rawValue ?? "unknown"
            let isFront = cameraManager?.isFrontCamera ?? false
            print("🔍 MetalRenderer diagnostic:")
            print("   📐 inputTexture: \(Int(inputWidth))x\(Int(inputHeight))")
            print("   🔄 rotation: \(rotation) rad (\(Int(rotation * 180 / .pi))°)")
            print("   📏 viewAspect: \(viewAspect), textureAspect: \(textureAspect)")
            print("   📷 camera: \(deviceType), isFront: \(isFront)")
            print("   🎭 mirror: \(mirror) (mirroring via AVCapture, not shader)")
            print("   📊 hasDepth: \(hasDepth)")
        }

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
        encoder.setFragmentTexture(depthTexture, index: 1)  // Depth texture at index 1
        
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()

        // Захватываем обработанный кадр ДО present (после present drawable недействителен)
        var capturedBuffer: CVPixelBuffer?
        if onRenderedFrame != nil {
            capturedBuffer = captureRenderedFrame(from: drawable.texture)
        }
        
        // Сохраняем флаги для callback
        let hasDepthBool = hasDepth > 0.5
        let depthAvailableCopy = depthAvailable
        
        commandBuffer.present(drawable)
        
        // Отправляем захваченный кадр после завершения GPU работы
        if let buffer = capturedBuffer {
            let callback = onRenderedFrame
            commandBuffer.addCompletedHandler { _ in
                callback?(buffer, hasDepthBool, depthAvailableCopy)
            }
        }
        
        commandBuffer.commit()
    }
    
    // MARK: - Capture Rendered Frame
    private func captureRenderedFrame(from texture: MTLTexture) -> CVPixelBuffer? {
        guard let pool = outputPixelBufferPool else { return nil }
        
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pixelBuffer)
        
        guard status == kCVReturnSuccess, let outputBuffer = pixelBuffer else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(outputBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(outputBuffer, []) }
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(outputBuffer) else { return nil }
        
        let bytesPerRow = CVPixelBufferGetBytesPerRow(outputBuffer)
        let bufferWidth = CVPixelBufferGetWidth(outputBuffer)
        let bufferHeight = CVPixelBufferGetHeight(outputBuffer)
        
        // Копируем точно по размерам буфера
        let region = MTLRegionMake2D(0, 0, bufferWidth, bufferHeight)
        texture.getBytes(baseAddress, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)
        
        return outputBuffer
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
    
    // MARK: - Depth Texture
    private func makeDepthTexture(from depthBuffer: CVPixelBuffer) -> MTLTexture? {
        let width = CVPixelBufferGetWidth(depthBuffer)
        let height = CVPixelBufferGetHeight(depthBuffer)
        
        // Определяем формат depth буфера
        let pixelFormat = CVPixelBufferGetPixelFormatType(depthBuffer)
        let metalFormat: MTLPixelFormat
        
        switch pixelFormat {
        case kCVPixelFormatType_DepthFloat32:
            metalFormat = .r32Float
        case kCVPixelFormatType_DepthFloat16:
            metalFormat = .r16Float
        case kCVPixelFormatType_DisparityFloat32:
            metalFormat = .r32Float
        case kCVPixelFormatType_DisparityFloat16:
            metalFormat = .r16Float
        default:
            print("⚠️ MetalRenderer: Unknown depth format: \(pixelFormat)")
            return nil
        }
        
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: metalFormat,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead]
        
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(depthBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthBuffer, .readOnly) }
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(depthBuffer) else {
            return nil
        }
        
        let bytesPerRow = CVPixelBufferGetBytesPerRow(depthBuffer)
        texture.replace(
            region: MTLRegionMake2D(0, 0, width, height),
            mipmapLevel: 0,
            withBytes: baseAddress,
            bytesPerRow: bytesPerRow
        )
        
        return texture
    }
}
