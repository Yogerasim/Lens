import SwiftUI
import AVKit

struct VideoPreviewPlayerView: UIViewControllerRepresentable {
    let url: URL
    var isMuted: Bool = true
    var shouldLoop: Bool = true

    func makeUIViewController(context: Context) -> PlayerViewController {
        let controller = PlayerViewController()
        controller.configure(url: url, isMuted: isMuted, shouldLoop: shouldLoop)
        return controller
    }

    func updateUIViewController(_ uiViewController: PlayerViewController, context: Context) {
        uiViewController.configure(url: url, isMuted: isMuted, shouldLoop: shouldLoop)
    }
}

final class PlayerViewController: AVPlayerViewController {
    private var currentURL: URL?
    private var queuePlayer: AVQueuePlayer?
    private var playerLooper: AVPlayerLooper?

    func configure(url: URL, isMuted: Bool, shouldLoop: Bool) {
        guard currentURL != url else {
            queuePlayer?.isMuted = isMuted
            return
        }

        currentURL = url

        let item = AVPlayerItem(url: url)
        let player = AVQueuePlayer()

        if shouldLoop {
            playerLooper = AVPlayerLooper(player: player, templateItem: item)
        } else {
            player.insert(item, after: nil)
            playerLooper = nil
        }

        player.isMuted = isMuted
        player.actionAtItemEnd = .none

        self.player = player
        self.queuePlayer = player

        showsPlaybackControls = true
        videoGravity = .resizeAspect

        player.play()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        queuePlayer?.pause()
    }
}
