import SwiftUI

struct ZoomPresetRow: View {

    @ObservedObject var cameraManager: CameraManager

    var body: some View {
        HStack(spacing: 14) {
            ForEach(ZoomPreset.allCases, id: \.self) { preset in
                let isSelected = abs(cameraManager.currentZoomFactor - preset.rawValue) < 0.02

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        cameraManager.zoom(to: preset)
                    }
                } label: {
                    Text(preset.title)
                        .font(.subheadline.bold())
                        .foregroundColor(isSelected ? .white : .white.opacity(0.75))
                        .glassChip(isSelected: isSelected)
                }
                .buttonStyle(.plain) // чтобы не ломать вид chip
            }
        }
    }
}
