import SwiftUI

struct ShaderIndicatorRow: View {

    @ObservedObject var shaderManager: ShaderManager

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(ShaderType.allCases.enumerated()), id: \.element) { index, _ in
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
