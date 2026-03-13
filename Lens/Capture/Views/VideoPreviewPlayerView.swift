import SwiftUI
import AVKit
import Combine

struct VideoPreviewPlayerView: View {
    let url: URL
    @StateObject private var coordinator = PlayerCoordinator()
    @State private var isPlaying = true
    @State private var showPlayButton = false
    
    var body: some View {
        ZStack {
            // Кастомный плеер без системных контролов
            PlayerLayerView(player: coordinator.player)
                .background(Color.black)
                .onTapGesture {
                    // Тап для паузы/воспроизведения
                    if isPlaying {
                        coordinator.pause()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            showPlayButton = true
                        }
                    } else {
                        coordinator.player.play()
                        withAnimation(.easeOut(duration: 0.2)) {
                            showPlayButton = false
                        }
                    }
                    isPlaying.toggle()
                }
            
            // Liquid Glass кнопка Play/Pause
            if showPlayButton {
                Button {
                    coordinator.player.play()
                    isPlaying = true
                    withAnimation(.easeOut(duration: 0.2)) {
                        showPlayButton = false
                    }
                } label: {
                    Image(systemName: "play.fill")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundColor(.white)
                }
                .glassCircle(size: 80)
                .transition(.scale(scale: 0.5).combined(with: .opacity))
            }
        }
        .onAppear {
            coordinator.setup(url: url)
            coordinator.play()
            isPlaying = true
            showPlayButton = false
        }
        .onDisappear {
            coordinator.pause()
        }
    }
}

/// UIViewRepresentable для AVPlayerLayer без системных контролов
struct PlayerLayerView: UIViewRepresentable {
    let player: AVPlayer
    
    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        view.player = player
        return view
    }
    
    func updateUIView(_ uiView: PlayerUIView, context: Context) {
        uiView.player = player
    }
}

class PlayerUIView: UIView {
    override class var layerClass: AnyClass {
        AVPlayerLayer.self
    }
    
    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }
    
    var player: AVPlayer? {
        get { playerLayer.player }
        set {
            playerLayer.player = newValue
            playerLayer.videoGravity = .resizeAspect
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
