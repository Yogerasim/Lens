import SwiftUI

struct ShaderIndicatorRow: View {
    @ObservedObject var shaderManager: ShaderManager
    @ObservedObject private var library = FilterLibrary.shared
    @ObservedObject private var framePipeline = FramePipeline.shared

    private var dotsCount: Int {
        let isFront = framePipeline.cameraManager?.isFrontCamera ?? false
        let isRecording = framePipeline.isRecording
        let family = framePipeline.recordingFilterFamily
        return library.availableFilters(isFront: isFront, recordingFamily: family, isRecording: isRecording).count
    }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<max(dotsCount, 1), id: \.self) { index in
                Circle()
                    .fill(index == shaderManager.currentIndex
                          ? Color.white.opacity(0.95)
                          : Color.white.opacity(0.25))
                    .frame(width: 8, height: 8)
            }
        }
        .glassPanel(cornerRadius: 18, padding: 10)
    }
}
