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

            CameraOverlay(
                cameraManager: cameraManager,
                shaderManager: shaderManager,
                mediaRecorder: mediaRecorder,
                fps: fps
            )
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
        FramePipeline.shared.cameraManager = cameraManager  // Для управления depth
        renderer.cameraManager = cameraManager

        renderer.onRenderedFrame = { renderedBuffer in
            if mediaRecorder.isRecording {
                let time = CMTime(seconds: CACurrentMediaTime(), preferredTimescale: 600)
                mediaRecorder.appendVideoFrame(renderedBuffer, at: time)
            } else {
                mediaRecorder.setLastRenderedFrame(renderedBuffer)
            }
        }

        cameraManager.onFrame = { pixelBuffer, time in
            let packet = FramePacket(pixelBuffer: pixelBuffer, time: time)
            FramePipeline.shared.gate.push(packet)
        }

        cameraManager.onAudioSample = { sampleBuffer in
            if mediaRecorder.isRecording {
                mediaRecorder.appendAudioSample(sampleBuffer)
            }
        }
    }
}
