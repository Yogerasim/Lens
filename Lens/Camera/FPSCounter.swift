import Foundation
import Combine

@MainActor
final class FPSCounter: ObservableObject {

    static let shared = FPSCounter()

    @Published var fps: Int = 0

    private var lastTime = CFAbsoluteTimeGetCurrent()
    private var frames = 0

    private init() {}

    nonisolated func tick() {
        Task { @MainActor in
            self.frames += 1
            let now = CFAbsoluteTimeGetCurrent()

            if now - self.lastTime >= 1.0 {
                self.fps = self.frames  // Сначала сохраняем
                print("📈 FPS =", self.fps)
                self.frames = 0         // Потом сбрасываем
                self.lastTime = now
            }
        }
    }
}
