import AVFAudio

final class AppAudioSessionController {
    static let shared = AppAudioSessionController()

    private init() {}

    func configureForCameraCapture() {
        let session = AVAudioSession.sharedInstance()

        do {
            // Проверяем, подключены ли наушники
            let headphonesConnected = isHeadphonesConnected(session: session)
            
            var options: AVAudioSession.CategoryOptions = [
                .mixWithOthers,
                .allowBluetoothA2DP
            ]
            
            // Если наушники НЕ подключены — используем основной динамик
            // Если подключены — НЕ добавляем defaultToSpeaker, чтобы звук шёл в наушники
            if !headphonesConnected {
                options.insert(.defaultToSpeaker)
            }
            
            try session.setCategory(
                .playAndRecord,
                mode: .default,
                options: options
            )

            try session.setActive(true, options: .notifyOthersOnDeactivation)
            
            DebugLog.info("AudioSession configured: headphones=\(headphonesConnected), defaultToSpeaker=\(!headphonesConnected)")
        } catch {
            DebugLog.error("AudioSession configure failed: \(error)")
        }
    }
    
    /// Проверяет, подключены ли наушники (проводные или Bluetooth)
    private func isHeadphonesConnected(session: AVAudioSession) -> Bool {
        let outputs = session.currentRoute.outputs
        
        for output in outputs {
            switch output.portType {
            case .headphones, .bluetoothA2DP, .bluetoothHFP, .bluetoothLE, .airPlay:
                return true
            default:
                continue
            }
        }
        
        return false
    }
    
    func deactivate() {
        let session = AVAudioSession.sharedInstance()
        
        do {
            try session.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            DebugLog.error("AudioSession deactivate failed: \(error)")
        }
    }
}
