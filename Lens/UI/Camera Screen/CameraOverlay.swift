import SwiftUI

struct CameraOverlay: View {

    // MARK: - Move only these two blocks (relative to safe areas)

    private let topBlockOffset    = CGPoint(x: 0, y: 0)  // +y = ниже от верха safe area
    private let bottomBlockOffset = CGPoint(x: 0, y: -310)  // +y = выше от низа safe area

    // MARK: - Internal layout (фиксированно внутри блоков)

    private let fpsOffset        = CGPoint(x: 0, y: 0)

    private let filtersOffset    = CGPoint(x: 0, y: -180)
    private let zoomOffset       = CGPoint(x: 0, y: -140)
    private let captureOffset    = CGPoint(x: 0, y: -50)
    private let modeOffset       = CGPoint(x: 0, y: 0)
    private let switchCamOffset  = CGPoint(x: 100, y: -70)
    private let effectsOffset    = CGPoint(x: -100, y: -70)

    // MARK: - Dependencies

    @ObservedObject var cameraManager: CameraManager
    @ObservedObject var shaderManager: ShaderManager
    @ObservedObject var mediaRecorder: MediaRecorder
    @ObservedObject var fps: FPSCounter

    var body: some View {
        // ВАЖНО: этот слой всегда занимает весь экран
        Color.clear
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()

            // ✅ TOP pinned
            .overlay(alignment: .top) {
                topBlock
                    .offset(x: topBlockOffset.x, y: topBlockOffset.y)
            }

            // ✅ BOTTOM pinned
            .overlay(alignment: .bottom) {
                bottomBlock
                    // для низа: +y должно поднимать вверх
                    .offset(x: bottomBlockOffset.x, y: -bottomBlockOffset.y)
            }
    }

    // MARK: - Top block (pinned)

    private var topBlock: some View {
        CameraTopBar(
            shaderManager: shaderManager,
            mediaRecorder: mediaRecorder,
            fps: fps
        )
        .offset(x: fpsOffset.x, y: fpsOffset.y)
        .padding(.top, 8) // небольшая “камера-айфон” поправка
    }

    // MARK: - Bottom block (pinned)

    private var bottomBlock: some View {
        ZStack {
            ShaderIndicatorRow(shaderManager: shaderManager)
                .offset(x: filtersOffset.x, y: filtersOffset.y)

            ZoomPresetRow(cameraManager: cameraManager)
                .offset(x: zoomOffset.x, y: zoomOffset.y)

            CaptureControls(
                cameraManager: cameraManager,
                mediaRecorder: mediaRecorder
            )
            .offset(x: captureOffset.x, y: captureOffset.y)

            CaptureModeSelector(mediaRecorder: mediaRecorder)
                .offset(x: modeOffset.x, y: modeOffset.y)
                .zIndex(10)

            Button { cameraManager.switchCamera() } label: {
                Image(systemName: "camera.rotate.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .glassCircle(size: 54)
            }
            .offset(x: switchCamOffset.x, y: switchCamOffset.y)

            Button { } label: {
                Image(systemName: "wand.and.stars")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(16)
                    .background(.black.opacity(0.6))
                    .clipShape(Circle())
            }
            .offset(x: effectsOffset.x, y: effectsOffset.y)
        }
        .padding(.bottom, 8) // аналогично — аккуратно отступить от края
    }
}

#Preview {
    CameraOverlay(
        cameraManager: CameraManager(),
        shaderManager: ShaderManager.shared,
        mediaRecorder: MediaRecorder(),
        fps: FPSCounter.shared
    )
    .background(Color.black)
}
