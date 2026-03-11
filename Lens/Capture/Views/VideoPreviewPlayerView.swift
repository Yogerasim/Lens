import SwiftUI
import AVKit
import Combine

struct VideoPreviewPlayerView: View {
    let url: URL
    @StateObject private var coordinator = PlayerCoordinator()
    
    var body: some View {
        VideoPlayer(player: coordinator.player)
            .background(Color.black)
            .onAppear {
                coordinator.setup(url: url)
                coordinator.play()
            }
            .onDisappear {
                coordinator.pause()
            }
    }
}

/// StateObject-based coordinator — AVPlayer живёт стабильно вне SwiftUI reinit cycles
private final class PlayerCoordinator: ObservableObject {
    let player = AVPlayer()
    private var endObserver: Any?
    
    func setup(url: URL) {
        // Убираем старый observer если view переиспользуется
        removeEndObserver()
        
        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        
        // Looping: при окончании — seek на начало и play
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            self?.player.seek(to: .zero)
            self?.player.play()
        }
    }
    
    func play() {
        player.seek(to: .zero)
        player.play()
    }
    
    func pause() {
        player.pause()
    }
    
    private func removeEndObserver() {
        if let obs = endObserver {
            NotificationCenter.default.removeObserver(obs)
            endObserver = nil
        }
    }
    
    deinit {
        removeEndObserver()
    }
}
