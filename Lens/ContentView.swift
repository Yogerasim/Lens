import SwiftUI
import CoreMedia

struct ContentView: View {

    @StateObject private var cameraManager = CameraManager()
    @StateObject private var fps = FPSCounter.shared
    @StateObject private var shaderManager = ShaderManager.shared
    @StateObject private var mediaRecorder = MediaRecorder()

    private let renderer = MetalRenderer(layer: CAMetalLayer())
    @State private var pinchStartZoom: CGFloat = 1.0

    var body: some View {
        ZStack {
            CameraCanvasView(
                renderer: renderer,
                cameraManager: cameraManager,
                shaderManager: shaderManager,
                pinchStartZoom: $pinchStartZoom
            )
            .ignoresSafeArea(.all)

            // UI поверх камеры
            VStack(spacing: 0) {
                // Верхняя панель
                topBar
                
                Spacer()
                
                // Нижняя панель
                bottomBar
            }
            .ignoresSafeArea(edges: .top)
        }
        .onAppear {
            setupRenderer()
            cameraManager.start()
        }
        .onDisappear {
            cameraManager.stop()
            if mediaRecorder.isRecording {
                mediaRecorder.stopRecording()
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Setup
    private func setupRenderer() {
        FramePipeline.shared.renderer = renderer
        
        // Связываем CameraManager с Renderer для правильной ориентации
        renderer.cameraManager = cameraManager

        // Callback для обработанных кадров с шейдером
        renderer.onRenderedFrame = { renderedBuffer in
            if self.mediaRecorder.isRecording {
                let time = CMTime(seconds: CACurrentMediaTime(), preferredTimescale: 600)
                self.mediaRecorder.appendVideoFrame(renderedBuffer, at: time)
            } else {
                self.mediaRecorder.setLastRenderedFrame(renderedBuffer)
            }
        }
        
        cameraManager.onFrame = { pixelBuffer, time in
            FramePipeline.shared.gate.push(
                pixelBuffer: pixelBuffer,
                time: time
            )
        }
        
        cameraManager.onAudioSample = { sampleBuffer in
            if self.mediaRecorder.isRecording {
                self.mediaRecorder.appendAudioSample(sampleBuffer)
            }
        }
    }
    
    // MARK: - Top Bar
    private var topBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(shaderManager.currentShader.rawValue.uppercased())
                    .font(.caption.bold())
                Text("FPS: \(fps.fps)")
                    .font(.system(.body, design: .monospaced))
            }
            .foregroundColor(.white)
            .padding(10)
            .background(.black.opacity(0.6))
            .cornerRadius(12)
            
            Spacer()
            
            if mediaRecorder.isRecording {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 10, height: 10)
                    Text(formatDuration(mediaRecorder.recordingDuration))
                        .font(.system(.body, design: .monospaced))
                }
                .foregroundColor(.white)
                .padding(10)
                .background(.red.opacity(0.7))
                .cornerRadius(12)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }
    
    // MARK: - Bottom Bar
    private var bottomBar: some View {
        VStack(spacing: 16) {
            HStack(spacing: 6) {
                ForEach(Array(ShaderType.allCases.enumerated()), id: \.element) { index, shader in
                    Circle()
                        .fill(index == shaderManager.currentIndex ? Color.white : Color.white.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(10)
            .background(.black.opacity(0.6))
            .cornerRadius(12)
            
            HStack(spacing: 20) {
                ForEach(ZoomPreset.allCases, id: \.self) { preset in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            cameraManager.zoom(to: preset)
                        }
                    }) {
                        Text(preset.title)
                            .font(.subheadline.bold())
                            .foregroundColor(
                                abs(cameraManager.currentZoomFactor - preset.rawValue) < 0.1
                                    ? .yellow
                                    : .white.opacity(0.8)
                            )
                            .frame(width: 44, height: 32)
                            .background(
                                abs(cameraManager.currentZoomFactor - preset.rawValue) < 0.1
                                    ? Color.white.opacity(0.2)
                                    : Color.clear
                            )
                            .cornerRadius(16)
                    }
                }
            }
            
            HStack(spacing: 20) {
                ForEach(CaptureMode.allCases, id: \.self) { mode in
                    Button(action: {
                        withAnimation {
                            mediaRecorder.captureMode = mode
                        }
                    }) {
                        Text(mode.rawValue)
                            .font(.subheadline.bold())
                            .foregroundColor(mediaRecorder.captureMode == mode ? .yellow : .white.opacity(0.6))
                    }
                }
            }
            
            HStack(alignment: .center, spacing: 0) {
                Button(action: {
                    cameraManager.switchCamera()
                }) {
                    Image(systemName: "camera.rotate.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .padding(16)
                        .background(.black.opacity(0.6))
                        .clipShape(Circle())
                }
                .frame(width: 70)
                
                Spacer()
                
                Button(action: {
                    handleCaptureButton()
                }) {
                    ZStack {
                        Circle()
                            .stroke(Color.white, lineWidth: 4)
                            .frame(width: 70, height: 70)
                        
                        if mediaRecorder.captureMode == .video {
                            if mediaRecorder.isRecording {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.red)
                                    .frame(width: 30, height: 30)
                            } else {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 54, height: 54)
                            }
                        } else {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 54, height: 54)
                        }
                    }
                }
                
                Spacer()
                
                Color.clear.frame(width: 70)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .padding(.bottom, 20)
    }
    
    // MARK: - Actions
    
    private func handleCaptureButton() {
        if mediaRecorder.captureMode == .video {
            if mediaRecorder.isRecording {
                mediaRecorder.stopRecording()
            } else {
                mediaRecorder.startRecording()
            }
        } else {
            // Фото
            mediaRecorder.takePhoto()
            // Haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        }
    }
    
    // MARK: - Helpers
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
