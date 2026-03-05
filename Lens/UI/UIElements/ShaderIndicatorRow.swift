import SwiftUI

struct ShaderIndicatorRow: View {
    @ObservedObject var shaderManager: ShaderManager

    private let fixedDotsCount = 5

    /// Активная точка: currentIndex по модулю 5 для циклического свечения
    private var activeDot: Int {
        shaderManager.currentIndex % fixedDotsCount
    }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<fixedDotsCount, id: \.self) { index in
                Circle()
                    .fill(index == activeDot
                          ? Color.white.opacity(0.95)
                          : Color.white.opacity(0.25))
                    .frame(width: 8, height: 8)
                    .animation(.easeInOut(duration: 0.15), value: activeDot)
            }
        }
        .glassPanel(cornerRadius: 18, padding: 10)
    }
}
