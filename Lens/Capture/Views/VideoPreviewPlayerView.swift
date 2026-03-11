import SwiftUI
import AVKit

struct VideoPreviewPlayerView: View {
    private let player: AVPlayer
    
    init(url: URL) {
        self.player = AVPlayer(url: url)
        self.player.isMuted = true
    }
    
    var body: some View {
        VideoPlayer(player: player)
            .background(Color.black)
            .onAppear {
                player.play()
            }
            .onDisappear {
                player.pause()
            }
    }
}
