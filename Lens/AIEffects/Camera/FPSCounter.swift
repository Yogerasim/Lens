import Foundation
import Combine

@MainActor
final class FPSCounter: ObservableObject {

    static let shared = FPSCounter()

    @Published var fps: Int = 0
    @Published var recordingFPS: Int = 0

    private var lastTime = CFAbsoluteTimeGetCurrent()
    private var frames = 0
    
    // Отдельный счетчик для записи видео
    private var recordingFrames = 0
    private var lastRecordingTime = CFAbsoluteTimeGetCurrent()

    private init() {}

    nonisolated func tick() {
        Task { @MainActor in
            self.frames += 1
            let now = CFAbsoluteTimeGetCurrent()

            if now - self.lastTime >= 1.0 {
                self.fps = self.frames  // Сначала сохраняем
                print("📈 Camera FPS =", self.fps)
                self.frames = 0         // Потом сбрасываем
                self.lastTime = now
            }
        }
    }
    
    nonisolated func tickRecording() {
        Task { @MainActor in
            self.recordingFrames += 1
            let now = CFAbsoluteTimeGetCurrent()
            
            if now - self.lastRecordingTime >= 1.0 {
                self.recordingFPS = self.recordingFrames
                print("🎬 Recording FPS =", self.recordingFPS)
                self.recordingFrames = 0
                self.lastRecordingTime = now
            }
        }
    }
}
