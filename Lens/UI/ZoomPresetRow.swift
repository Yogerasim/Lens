import SwiftUI

struct ZoomPresetRow: View {

    @ObservedObject var cameraManager: CameraManager

    var body: some View {
        HStack(spacing: 20) {
            ForEach(ZoomPreset.allCases, id: \.self) { preset in
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        cameraManager.zoom(to: preset)
                    }
                } label: {
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
    }
}
