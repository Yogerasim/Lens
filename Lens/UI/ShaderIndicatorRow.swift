import SwiftUI

struct ShaderIndicatorRow: View {

    @ObservedObject var shaderManager: ShaderManager

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(ShaderType.allCases.enumerated()), id: \.element) { index, _ in
                Circle()
                    .fill(index == shaderManager.currentIndex
                          ? Color.white
                          : Color.white.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
        .padding(10)
        .background(.black.opacity(0.6))
        .cornerRadius(12)
    }
}
