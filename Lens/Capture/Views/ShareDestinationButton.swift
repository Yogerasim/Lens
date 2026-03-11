import SwiftUI

struct ShareDestinationButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .semibold))
                
                Text(title)
                    .font(.caption)
                    .lineLimit(1)
            }
            .foregroundColor(.white)
            .frame(width: 72, height: 72)
            .background(Color.white.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}
