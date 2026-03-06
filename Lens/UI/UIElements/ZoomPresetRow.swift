internal import AVFoundation
import SwiftUI

struct ZoomPresetRow: View {

  @ObservedObject var cameraManager: CameraManager

  var body: some View {
    HStack(spacing: 14) {
      ForEach(availablePresets, id: \.self) { preset in
        let isSelected = isPresetSelected(preset)

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
        .buttonStyle(.plain)
      }
    }
  }

  private func isPresetSelected(_ preset: ZoomPreset) -> Bool {
    let current = cameraManager.currentZoomFactor

    switch preset {
    case .ultraWide:
      return abs(current - 0.5) < 0.12
    case .wide:
      return abs(current - 1.0) < 0.16
    case .telephoto:
      return abs(current - 2.0) < 0.22
    }
  }

  private var availablePresets: [ZoomPreset] {
    if cameraManager.isDepthEnabled {
      return [.wide]
    }

    if cameraManager.currentPosition == .front {
      return [.wide]
    }

    var result: [ZoomPreset] = []

    if cameraManager.hasUltraWideForUI {
      result.append(.ultraWide)
    }

    result.append(.wide)

    if cameraManager.hasTelephotoForUI {
      result.append(.telephoto)
    }

    return result
  }
}
