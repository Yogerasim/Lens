import AVFAudio

final class AppAudioSessionController {
  static let shared = AppAudioSessionController()

  private init() {}

  func configureForCameraCapture() {
    let session = AVAudioSession.sharedInstance()

    do {
      try session.setCategory(
        .playAndRecord,
        mode: .videoRecording,
        options: [
          .mixWithOthers,
          .defaultToSpeaker,
          .allowBluetooth
        ]
      )

      try session.setActive(true)
    } catch {
      DebugLog.error("AudioSession configure failed: \(error)")
    }
  }
}
