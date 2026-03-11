import SwiftUI

struct ZoomGlassBar: View {
    @ObservedObject var cameraManager: CameraManager
    let isDepthMode: Bool
    let isFrontCamera: Bool

    @State private var isDragging = false

    private var presets: [ZoomPresetItem] {
        if isDepthMode || isFrontCamera {
            if cameraManager.hasTelephotoForUI {
                return [
                    ZoomPresetItem(label: "1", factor: 1.0),
                    ZoomPresetItem(label: "2", factor: 2.0),
                    ZoomPresetItem(label: "9", factor: 9.0)
                ]
            } else {
                return [
                    ZoomPresetItem(label: "1", factor: 1.0),
                    ZoomPresetItem(label: "9", factor: 9.0)
                ]
            }
        }

        let hasUltra = cameraManager.hasUltraWideForUI
        let hasTele = cameraManager.hasTelephotoForUI

        switch (hasUltra, hasTele) {
        case (true, true):
            return [
                ZoomPresetItem(label: "0.5", factor: 0.5),
                ZoomPresetItem(label: "1", factor: 1.0),
                ZoomPresetItem(label: "2", factor: 2.0),
                ZoomPresetItem(label: "9", factor: 9.0)
            ]
        case (false, true):
            return [
                ZoomPresetItem(label: "1", factor: 1.0),
                ZoomPresetItem(label: "2", factor: 2.0),
                ZoomPresetItem(label: "9", factor: 9.0)
            ]
        case (true, false):
            return [
                ZoomPresetItem(label: "0.5", factor: 0.5),
                ZoomPresetItem(label: "1", factor: 1.0),
                ZoomPresetItem(label: "9", factor: 9.0)
            ]
        case (false, false):
            return [
                ZoomPresetItem(label: "1", factor: 1.0),
                ZoomPresetItem(label: "9", factor: 9.0)
            ]
        }
    }

    private var minZoom: CGFloat {
        if isDepthMode || isFrontCamera {
            return 1.0
        }
        return cameraManager.hasUltraWideForUI ? 0.5 : 1.0
    }

    private var maxZoom: CGFloat {
        max(1.0, cameraManager.maxDigitalZoomForUI)
    }

    private var currentZoom: CGFloat {
        min(max(cameraManager.currentZoomFactor, minZoom), maxZoom)
    }

    private var zoomDisplayText: String {
        let z = currentZoom
        if z < 1.0 {
            return String(format: "%.1f×", z)
        } else if z == floor(z), z <= 9 {
            return String(format: "%.0f×", z)
        } else {
            return String(format: "%.1f×", z)
        }
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let innerWidth = max(1, width - 20)
            let thumbX = xPosition(for: currentZoom, in: innerWidth) + 10

            ZStack {
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.14), lineWidth: 0.5)
                    )

                Capsule()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 30)
                    .padding(.horizontal, 10)

                Circle()
                    .fill(Color.yellow.opacity(0.92))
                    .frame(width: 34, height: 34)
                    .overlay(
                        Text(zoomDisplayText)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.black)
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                    )
                    .position(x: thumbX, y: geo.size.height / 2)

                HStack(spacing: 0) {
                    ForEach(presets) { preset in
                        Button {
                            cameraManager.jumpToPreset(logical: preset.factor)
                        } label: {
                            Text("\(preset.label)×")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundColor(labelColor(for: preset.factor))
                                .frame(maxWidth: .infinity)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
            }
            .contentShape(Capsule())
            .highPriorityGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            cameraManager.zoomGestureBegan()
                        }

                        let localX = min(max(value.location.x - 10, 0), innerWidth)
                        let requestedZoom = zoomValue(for: localX, in: innerWidth)
                        cameraManager.zoomGestureChanged(logicalZoom: requestedZoom)
                    }
                    .onEnded { value in
                        let localX = min(max(value.location.x - 10, 0), innerWidth)
                        let requestedZoom = zoomValue(for: localX, in: innerWidth)
                        cameraManager.zoomGestureEnded(targetLogicalZoom: requestedZoom)
                        isDragging = false
                    }
            )
        }
        .frame(height: 44)
        .animation(.easeInOut(duration: 0.12), value: currentZoom)
    }

    private func labelColor(for factor: CGFloat) -> Color {
        let diff = abs(currentZoom - factor)

        if factor < 1.0 {
            return diff < 0.12 ? .black.opacity(0.001) : .white.opacity(0.78)
        } else if factor <= 2.0 {
            return diff < 0.20 ? .black.opacity(0.001) : .white.opacity(0.78)
        } else {
            return diff < 0.45 ? .black.opacity(0.001) : .white.opacity(0.78)
        }
    }

    private func xPosition(for zoom: CGFloat, in width: CGFloat) -> CGFloat {
        let logMin = log(minZoom)
        let logMax = log(maxZoom)
        let clampedZoom = min(max(zoom, minZoom), maxZoom)
        let normalized = (log(clampedZoom) - logMin) / (logMax - logMin)
        return normalized * width
    }

    private func zoomValue(for x: CGFloat, in width: CGFloat) -> CGFloat {
        let logMin = log(minZoom)
        let logMax = log(maxZoom)
        let normalized = min(max(x / max(width, 1), 0), 1)
        let logZoom = logMin + normalized * (logMax - logMin)
        return exp(logZoom)
    }
}

private struct ZoomPresetItem: Identifiable {
    let id = UUID()
    let label: String
    let factor: CGFloat
}
