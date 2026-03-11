import SwiftUI

struct ZoomGlassBar: View {
    @ObservedObject var cameraManager: CameraManager
    let isDepthMode: Bool
    let isFrontCamera: Bool

    @State private var isDragging = false

    private var presets: [ZoomPresetItem] {
        if isDepthMode || isFrontCamera {
            return [
                ZoomPresetItem(label: "1×", factor: 1.0),
                ZoomPresetItem(label: "2×", factor: 2.0),
                ZoomPresetItem(label: "9×", factor: 9.0)
            ]
        }

        let hasUltra = cameraManager.hasUltraWideForUI
        let hasTele = cameraManager.hasTelephotoForUI

        switch (hasUltra, hasTele) {
        case (true, true):
            return [
                ZoomPresetItem(label: "0.5×", factor: 0.5),
                ZoomPresetItem(label: "1×", factor: 1.0),
                ZoomPresetItem(label: "2×", factor: 2.0),
                ZoomPresetItem(label: "9×", factor: 9.0)
            ]
        case (false, true):
            return [
                ZoomPresetItem(label: "1×", factor: 1.0),
                ZoomPresetItem(label: "2×", factor: 2.0),
                ZoomPresetItem(label: "9×", factor: 9.0)
            ]
        case (true, false):
            return [
                ZoomPresetItem(label: "0.5×", factor: 0.5),
                ZoomPresetItem(label: "1×", factor: 1.0),
                ZoomPresetItem(label: "9×", factor: 9.0)
            ]
        case (false, false):
            return [
                ZoomPresetItem(label: "1×", factor: 1.0),
                ZoomPresetItem(label: "9×", factor: 9.0)
            ]
        }
    }

    private var minZoom: CGFloat {
        if isDepthMode || isFrontCamera { return 1.0 }
        return cameraManager.hasUltraWideForUI ? 0.5 : 1.0
    }

    private var maxZoom: CGFloat {
        max(cameraManager.maxDigitalZoomForUI, minZoom)
    }

    private var currentZoom: CGFloat {
        clamp(cameraManager.currentZoomFactor, minZoom, maxZoom)
    }

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 0) {
                ForEach(presets) { preset in
                    Button {
                        print("ZOOM BAR TAP preset=\(preset.factor)")
                        cameraManager.jumpToPreset(logical: preset.factor)
                    } label: {
                        Text(preset.label)
                            .font(.system(size: 11, weight: isNear(preset.factor) ? .bold : .semibold, design: .rounded))
                            .foregroundStyle(isNear(preset.factor) ? .white : .white.opacity(0.58))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }

            GeometryReader { geo in
                let sideInset: CGFloat = 10
                let trackWidth = max(1, geo.size.width - sideInset * 2)
                let thumbX = xPosition(for: currentZoom, width: trackWidth) + sideInset

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.10))
                        .frame(height: 6)

                    presetTicks(width: trackWidth)
                        .padding(.horizontal, sideInset)

                    Circle()
                        .fill(Color.white)
                        .frame(width: 16, height: 16)
                        .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 4)
                        .offset(x: thumbX - 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .contentShape(Rectangle())
                .highPriorityGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let localX = clamp(value.location.x - sideInset, 0, trackWidth)
                            let requestedZoom = zoomValue(for: localX, width: trackWidth)

                            if !isDragging {
                                isDragging = true
                                DebugLog.zoom("ZoomGlassBar drag begin current=\(currentZoom) min=\(minZoom) max=\(maxZoom)")
                                cameraManager.zoomGestureBegan()
                            }

                            DebugLog.zoom("ZoomGlassBar drag changed x=\(localX) requested=\(requestedZoom)")
                            cameraManager.zoomGestureChanged(logicalZoom: requestedZoom)
                        }
                        .onEnded { value in
                            let localX = clamp(value.location.x - sideInset, 0, trackWidth)
                            let targetZoom = zoomValue(for: localX, width: trackWidth)

                            print("ZOOM BAR DRAG ENDED target=\(targetZoom)")
                            cameraManager.zoomGestureEnded(targetLogicalZoom: targetZoom)
                            isDragging = false
                        }
                )
                .onAppear {
                    DebugLog.zoom("ZoomGlassBar appear current=\(currentZoom) min=\(minZoom) max=\(maxZoom) depth=\(isDepthMode) front=\(isFrontCamera)")
                }
                .onChange(of: cameraManager.currentZoomFactor) { _, newValue in
                    DebugLog.zoom("ZoomGlassBar currentZoomFactor updated -> \(newValue)")
                }
                .onChange(of: isDepthMode) { _, newValue in
                    DebugLog.zoom("ZoomGlassBar isDepthMode changed -> \(newValue), min=\(minZoom), max=\(maxZoom)")
                }
                .onChange(of: isFrontCamera) { _, newValue in
                    DebugLog.zoom("ZoomGlassBar isFrontCamera changed -> \(newValue), min=\(minZoom), max=\(maxZoom)")
                }
            }
            .frame(height: 18)
        }
        .glassPanel(cornerRadius: 20, padding: 10)
    }

    @ViewBuilder
    private func presetTicks(width: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            ForEach(presets) { preset in
                Capsule()
                    .fill(Color.white.opacity(isNear(preset.factor) ? 0.75 : 0.28))
                    .frame(width: 2, height: 8)
                    .offset(x: xPosition(for: preset.factor, width: width) - 1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func xPosition(for zoom: CGFloat, width: CGFloat) -> CGFloat {
        let logMin = log(minZoom)
        let logMax = log(maxZoom)
        let clamped = clamp(zoom, minZoom, maxZoom)
        let normalized = (log(clamped) - logMin) / max(logMax - logMin, 0.0001)
        return normalized * width
    }

    private func zoomValue(for x: CGFloat, width: CGFloat) -> CGFloat {
        let normalized = clamp(x / max(width, 1), 0, 1)
        let logMin = log(minZoom)
        let logMax = log(maxZoom)
        let logZoom = logMin + normalized * (logMax - logMin)
        return exp(logZoom)
    }

    private func isNear(_ factor: CGFloat) -> Bool {
        let diff = abs(currentZoom - factor)
        if factor < 1.0 { return diff < 0.12 }
        if factor <= 2.0 { return diff < 0.22 }
        return diff < 0.6
    }

    private func clamp<T: Comparable>(_ value: T, _ minValue: T, _ maxValue: T) -> T {
        min(max(value, minValue), maxValue)
    }
}

private struct ZoomPresetItem: Identifiable {
    let id = UUID()
    let label: String
    let factor: CGFloat
}
