import SwiftUI

struct ZoomPresetRow: View {

    @ObservedObject var cameraManager: CameraManager

    var body: some View {
        HStack(spacing: 14) {
            ForEach(availablePresets, id: \.self) { preset in
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
    
    /// Доступные зум пресеты в зависимости от состояния depth
    private var availablePresets: [ZoomPreset] {
        let depthMode = FramePipeline.shared.activeFilter?.needsDepth == true || cameraManager.isDepthEnabled
        
        if depthMode {
            // Когда depth включён или фильтр требует depth — показываем только 1x (LiDAR работает только на wide)
            return [.wide]
        } else {
            // Когда depth выключен — показываем все пресеты
            return ZoomPreset.allCases
        }
    }
}
