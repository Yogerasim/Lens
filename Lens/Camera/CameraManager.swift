import AVFoundation
import CoreVideo
import Combine

final class CameraManager: NSObject, ObservableObject {
    
    // MARK: - Public
    let session = AVCaptureSession()
    
    /// Замыкание для получения кадра
    var onFrame: ((CVPixelBuffer, CMTime) -> Void)?
    
    /// Замыкание для получения аудио сэмплов
    var onAudioSample: ((CMSampleBuffer) -> Void)?
    
    /// Текущая позиция камеры
    @Published var currentPosition: AVCaptureDevice.Position = .back
    
    // MARK: - Private
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private let outputQueue = DispatchQueue(label: "camera.output.queue")
    private let audioOutputQueue = DispatchQueue(label: "camera.audio.queue")
    private let videoOutput = AVCaptureVideoDataOutput()
    private let audioOutput = AVCaptureAudioDataOutput()
    private var currentInput: AVCaptureDeviceInput?
    private var audioInput: AVCaptureDeviceInput?
    
    // MARK: - Init
    override init() {
        super.init()
        configureSession()
    }
    
    // MARK: - Start/Stop
    func start() {
        // Сначала проверяем/запрашиваем разрешение на камеру
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            requestAudioPermissionAndStart()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    self.requestAudioPermissionAndStart()
                } else {
                    print("❌ Camera access denied")
                }
            }
        default:
            print("❌ Camera access denied or restricted")
        }
    }
    
    private func requestAudioPermissionAndStart() {
        // Запрашиваем разрешение на микрофон
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            startSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                // Запускаем даже если микрофон запрещён (просто без звука)
                self.startSession()
            }
        default:
            // Запускаем без микрофона
            startSession()
        }
    }
    
    private func startSession() {
        sessionQueue.async {
            if !self.session.isRunning {
                self.session.startRunning()
                print("✅ Camera session started")
            }
        }
    }
    
    func stop() {
        sessionQueue.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }
    
    // MARK: - Switch Camera
    func switchCamera() {
        sessionQueue.async {
            let newPosition: AVCaptureDevice.Position = self.currentPosition == .back ? .front : .back
            
            guard let newDevice = AVCaptureDevice.default(
                .builtInWideAngleCamera,
                for: .video,
                position: newPosition
            ) else {
                print("❌ Camera for position \(newPosition) not available")
                return
            }
            
            do {
                let newInput = try AVCaptureDeviceInput(device: newDevice)
                
                self.session.beginConfiguration()
                
                // Удаляем старый input
                if let currentInput = self.currentInput {
                    self.session.removeInput(currentInput)
                }
                
                // Выбираем оптимальный preset для камеры
                let preferredPreset: AVCaptureSession.Preset = newPosition == .front ? .hd1280x720 : .hd1920x1080
                if self.session.canSetSessionPreset(preferredPreset) {
                    self.session.sessionPreset = preferredPreset
                } else {
                    self.session.sessionPreset = .high
                }
                
                // Добавляем новый input
                if self.session.canAddInput(newInput) {
                    self.session.addInput(newInput)
                    self.currentInput = newInput
                    
                    DispatchQueue.main.async {
                        self.currentPosition = newPosition
                    }
                    print("📷 Switched to \(newPosition == .front ? "front" : "back") camera")
                }
                
                // Обновляем ориентацию для нового connection
                if let connection = self.videoOutput.connection(with: .video) {
                    if #available(iOS 17.0, *) {
                        connection.videoRotationAngle = 90
                    } else {
                        connection.videoOrientation = .portrait
                    }
                    
                    // Зеркалим фронтальную камеру
                    if newPosition == .front {
                        connection.isVideoMirrored = true
                    }
                }
                
                self.session.commitConfiguration()
                
            } catch {
                print("❌ Failed to switch camera:", error)
            }
        }
    }
    
    // MARK: - Configuration
    private func configureSession() {
        sessionQueue.async {
            self.session.beginConfiguration()
            self.session.sessionPreset = .hd1920x1080
            
            // Camera Input
            guard let device = AVCaptureDevice.default(
                .builtInWideAngleCamera,
                for: .video,
                position: .back
            ) else {
                print("❌ Camera not available")
                self.session.commitConfiguration()
                return
            }
            
            do {
                let input = try AVCaptureDeviceInput(device: device)
                if self.session.canAddInput(input) {
                    self.session.addInput(input)
                    self.currentInput = input
                }
            } catch {
                print("❌ Camera input error:", error)
                self.session.commitConfiguration()
                return
            }
            
            // Video Output
            self.videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String:
                    kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
            ]
            self.videoOutput.alwaysDiscardsLateVideoFrames = true
            self.videoOutput.setSampleBufferDelegate(self, queue: self.outputQueue)
            
            if self.session.canAddOutput(self.videoOutput) {
                self.session.addOutput(self.videoOutput)
            }
            
            // Audio Input
            if let audioDevice = AVCaptureDevice.default(for: .audio) {
                do {
                    let audioDeviceInput = try AVCaptureDeviceInput(device: audioDevice)
                    if self.session.canAddInput(audioDeviceInput) {
                        self.session.addInput(audioDeviceInput)
                        self.audioInput = audioDeviceInput
                        print("✅ Audio input added")
                    }
                } catch {
                    print("⚠️ Could not add audio input: \(error)")
                }
            }
            
            // Audio Output
            self.audioOutput.setSampleBufferDelegate(self, queue: self.audioOutputQueue)
            if self.session.canAddOutput(self.audioOutput) {
                self.session.addOutput(self.audioOutput)
                print("✅ Audio output added")
            }
            
            // Orientation
            if let connection = self.videoOutput.connection(with: .video) {
                if #available(iOS 17.0, *) {
                    connection.videoRotationAngle = 90  // Portrait mode
                } else {
                    connection.videoOrientation = .portrait
                }
            }
            
            self.session.commitConfiguration()
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate & AVCaptureAudioDataOutputSampleBufferDelegate
extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        if output == videoOutput {
            // Video
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            onFrame?(pixelBuffer, time)
        } else if output == audioOutput {
            // Audio
            onAudioSample?(sampleBuffer)
        }
    }
}
