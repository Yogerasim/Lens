import SwiftUI
import UIKit

struct CameraOverlay: View {

    private let topBlockOffset    = CGPoint(x: 0, y: 0)
    private let bottomBlockOffset = CGPoint(x: 0, y: -310)

    private let fpsOffset        = CGPoint(x: 0, y: 0)

    private let filtersOffset    = CGPoint(x: 0, y: -180)
    private let zoomOffset       = CGPoint(x: 0, y: -140)
    private let captureOffset    = CGPoint(x: 0, y: -50)
    private let modeOffset       = CGPoint(x: 0, y: 0)
    private let switchCamOffset  = CGPoint(x: 100, y: -70)
    private let effectsOffset    = CGPoint(x: -100, y: -70)

    private let demoOffset       = CGPoint(x: 0, y: -70)

    @ObservedObject var cameraManager: CameraManager
    @ObservedObject var shaderManager: ShaderManager
    @ObservedObject var mediaRecorder: MediaRecorder
    @ObservedObject var fps: FPSCounter
    @ObservedObject var framePipeline = FramePipeline.shared

    @State private var isDemoPresented = false
    @State private var isMediaHubPresented = false
    @State private var isLegacyHubPresented = false
    @State private var isFlashing = false

    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()

            .overlay(alignment: .top) {
                topBlock
                    .offset(x: topBlockOffset.x, y: topBlockOffset.y)
            }

            .overlay(alignment: .bottom) {
                bottomBlock
                    .offset(x: bottomBlockOffset.x, y: -bottomBlockOffset.y)
            }

            .overlay {
                if isFlashing {
                    Rectangle()
                        .fill(Color.black)
                        .ignoresSafeArea()
                        .opacity(0.8)
                        .allowsHitTesting(false)
                }
            }

            .sheet(isPresented: $isMediaHubPresented) {
                MediaHubTabView(
                    onClose: {
                        isMediaHubPresented = false
                        print("📱 MediaHub closed")
                    },
                    onSelectEffect: { filter in
                        shaderManager.selectShader(by: filter.shaderName)
                        print("🎨 Selected filter: \(filter.name), shader: \(filter.shaderName), needsDepth: \(filter.needsDepth)")
                    },
                    cameraManager: cameraManager,
                    shaderManager: shaderManager,
                    mediaRecorder: mediaRecorder,
                    framePipeline: framePipeline
                )
            }

            .sheet(isPresented: $isLegacyHubPresented) {
                LegacyMediaHubTabView(
                    onClose: { isLegacyHubPresented = false },
                    onSelectEffect: { filter in
                        shaderManager.selectShader(by: filter.shaderName)
                    }
                )
            }

            .sheet(isPresented: $isDemoPresented) {
                ShaderDemoControls()
            }
    }

    private var topBlock: some View {
        CameraTopBar(
            shaderManager: shaderManager,
            mediaRecorder: mediaRecorder,
            fps: fps
        )
        .offset(x: fpsOffset.x, y: fpsOffset.y)
        .padding(.top, 8)
    }

    private var bottomBlock: some View {
        ZStack {
            ShaderIndicatorRow(shaderManager: shaderManager)
                .offset(x: filtersOffset.x, y: filtersOffset.y)

            ZoomPresetRow(cameraManager: cameraManager)
                .offset(x: zoomOffset.x, y: zoomOffset.y)

            CaptureControls(
                cameraManager: cameraManager,
                mediaRecorder: mediaRecorder,
                isFlashing: $isFlashing
            )
            .offset(x: captureOffset.x, y: captureOffset.y)

            CaptureModeSelector(mediaRecorder: mediaRecorder)
                .offset(x: modeOffset.x, y: modeOffset.y)
                .zIndex(10)

            if !framePipeline.isDepthModeActive {
                Button { cameraManager.switchCamera() } label: {
                    Image(systemName: "camera.rotate.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .glassCircle(size: 54)
                }
                .offset(x: switchCamOffset.x, y: switchCamOffset.y)
            }

            Button {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()

                shaderManager.stopDemo()

                isMediaHubPresented = true
            } label: {
                Image(systemName: "wand.and.stars")
                    .font(.title2)
                    .foregroundColor(.white)
                    .glassCircle(size: 54)
            }
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.5)
                    .onEnded { _ in
                        let generator = UIImpactFeedbackGenerator(style: .heavy)
                        generator.impactOccurred()

                        shaderManager.stopDemo()

                        isLegacyHubPresented = true
                    }
            )
            .offset(x: effectsOffset.x, y: effectsOffset.y)

            Button {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                isDemoPresented = true
            } label: {
                Image(systemName: "shuffle")
                    .font(.title2)
                    .foregroundColor(.white)
                    .glassCircle(size: 54)
            }
            .offset(x: demoOffset.x, y: demoOffset.y)
        }
        .padding(.bottom, 8)
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
