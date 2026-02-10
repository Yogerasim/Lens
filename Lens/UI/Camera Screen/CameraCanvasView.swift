import SwiftUI

struct CameraCanvasView: View {

    let renderer: MetalRenderer

    @ObservedObject var cameraManager: CameraManager
    @ObservedObject var shaderManager: ShaderManager

    @Binding var pinchStartZoom: CGFloat

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            MetalView(renderer: renderer)
                .aspectRatio(9.0 / 16.0, contentMode: .fit)
                .gesture(cameraGestures)
        }
    }

    private var cameraGestures: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                if abs(value - 1.0) < 0.02 {
                    pinchStartZoom = cameraManager.currentZoomFactor
                }
                cameraManager.setZoom(pinchStartZoom * value)
            }
            .onEnded { _ in
                pinchStartZoom = cameraManager.currentZoomFactor
            }
            .simultaneously(with:
                DragGesture(minimumDistance: 50)
                    .onEnded { value in
                        if value.translation.width < -50 {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                shaderManager.nextShader()
                            }
                        } else if value.translation.width > 50 {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                shaderManager.previousShader()
                            }
                        }
                    }
            )
    }
}
