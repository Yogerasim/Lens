internal import AVFoundation
import Combine
import Foundation
import Speech

@MainActor
final class SpeechService: ObservableObject {

  @Published private(set) var isListening: Bool = false
  @Published private(set) var permissionStatus: PermissionStatus = .notDetermined

  enum PermissionStatus {
    case notDetermined
    case authorized
    case denied
    case restricted
  }

  private var speechRecognizer: SFSpeechRecognizer?
  private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
  private var recognitionTask: SFSpeechRecognitionTask?
  private let audioEngine = AVAudioEngine()

  private var onPartial: ((String) -> Void)?
  private var onFinal: ((String) -> Void)?
  private var onError: ((Error) -> Void)?

  init() {
    speechRecognizer = SFSpeechRecognizer(locale: Locale.current)
  }

  func requestPermissions() async -> Bool {

    let microphoneGranted = await withCheckedContinuation { continuation in
      AVAudioApplication.requestRecordPermission { granted in
        continuation.resume(returning: granted)
      }
    }

    guard microphoneGranted else {
      permissionStatus = .denied
      DebugLog.voice("SpeechService: Microphone permission denied")
      return false
    }

    let speechGranted = await withCheckedContinuation { continuation in
      SFSpeechRecognizer.requestAuthorization { status in
        continuation.resume(returning: status == .authorized)
      }
    }

    if speechGranted {
      permissionStatus = .authorized
      return true
    } else {
      permissionStatus = .denied
      DebugLog.voice("SpeechService: Speech recognition permission denied")
      return false
    }
  }

  func start(
    locale: Locale = .current,
    onPartial: @escaping (String) -> Void,
    onFinal: @escaping (String) -> Void,
    onError: @escaping (Error) -> Void
  ) {
    guard !isListening else {
      return
    }

    guard permissionStatus == .authorized else {
      onError(SpeechError.permissionDenied)
      return
    }

    self.onPartial = onPartial
    self.onFinal = onFinal
    self.onError = onError

    speechRecognizer = SFSpeechRecognizer(locale: locale)

    guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
      onError(SpeechError.recognizerUnavailable)
      return
    }

    do {
      try startAudioEngine()
      isListening = true
    } catch {
      onError(error)
      DebugLog.voice("SpeechService: Failed to start - \(error.localizedDescription)")
    }
  }

  func stop() {
    guard isListening else { return }

    audioEngine.stop()
    audioEngine.inputNode.removeTap(onBus: 0)

    recognitionRequest?.endAudio()
    recognitionRequest = nil

    recognitionTask?.cancel()
    recognitionTask = nil

    isListening = false
  }

  private func startAudioEngine() throws {

    recognitionTask?.cancel()
    recognitionTask = nil

    let audioSession = AVAudioSession.sharedInstance()
    try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
    try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

    recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

    guard let recognitionRequest = recognitionRequest else {
      throw SpeechError.requestCreationFailed
    }

    recognitionRequest.shouldReportPartialResults = true
    recognitionRequest.requiresOnDeviceRecognition = false

    recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) {
      [weak self] result, error in
      Task { @MainActor in
        self?.handleRecognitionResult(result: result, error: error)
      }
    }

    let inputNode = audioEngine.inputNode
    let recordingFormat = inputNode.outputFormat(forBus: 0)

    inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) {
      [weak self] buffer, _ in
      self?.recognitionRequest?.append(buffer)
    }

    audioEngine.prepare()
    try audioEngine.start()
  }

  private func handleRecognitionResult(result: SFSpeechRecognitionResult?, error: Error?) {
    if let error = error {

      if (error as NSError).code != 1 && (error as NSError).code != 216 {
        onError?(error)
      }
      stop()
      return
    }

    guard let result = result else { return }

    let transcription = result.bestTranscription.formattedString

    if result.isFinal {
      onFinal?(transcription)
      stop()
    } else {
      onPartial?(transcription)
    }
  }
}

enum SpeechError: LocalizedError {
  case permissionDenied
  case recognizerUnavailable
  case requestCreationFailed

  var errorDescription: String? {
    switch self {
    case .permissionDenied:
      return "Нет разрешения на распознавание речи"
    case .recognizerUnavailable:
      return "Распознавание речи недоступно"
    case .requestCreationFailed:
      return "Не удалось создать запрос распознавания"
    }
  }
}
