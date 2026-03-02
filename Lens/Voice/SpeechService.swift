import Foundation
import Speech
internal import AVFoundation
import Combine

/// Сервис распознавания речи через Apple Speech Framework
@MainActor
final class SpeechService: ObservableObject {
    
    // MARK: - Published State
    
    @Published private(set) var isListening: Bool = false
    @Published private(set) var permissionStatus: PermissionStatus = .notDetermined
    
    enum PermissionStatus {
        case notDetermined
        case authorized
        case denied
        case restricted
    }
    
    // MARK: - Private Properties
    
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    private var onPartial: ((String) -> Void)?
    private var onFinal: ((String) -> Void)?
    private var onError: ((Error) -> Void)?
    
    // Защита от двойного вызова onFinal
    private var lastFinalText: String = ""
    private var hasFiredFinal: Bool = false
    
    // Поддерживаемые локали с приоритетом
    private let preferredLocales: [Locale] = [
        Locale(identifier: "ru-RU"),  // Приоритет русскому
        Locale(identifier: "en-US")   // Fallback английский
    ]
    
    // MARK: - Init
    
    init() {
        // Инициализируем с русской локалью по умолчанию
        speechRecognizer = SFSpeechRecognizer(locale: preferredLocales[0])
    }
    
    // MARK: - Permissions
    
    /// Запрашивает разрешения на микрофон и распознавание речи
    func requestPermissions() async -> Bool {
        // 1. Запрос разрешения на микрофон
        let microphoneGranted = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        
        guard microphoneGranted else {
            permissionStatus = .denied
            print("🎤 SpeechService: Microphone permission denied")
            return false
        }
        
        // 2. Запрос разрешения на Speech Recognition
        let speechGranted = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        
        if speechGranted {
            permissionStatus = .authorized
            print("🎤 SpeechService: All permissions granted")
            return true
        } else {
            permissionStatus = .denied
            print("🎤 SpeechService: Speech recognition permission denied")
            return false
        }
    }
    
    // MARK: - Start/Stop Recognition
    
    /// Начинает распознавание речи с автовыбором локали
    func start(
        onPartial: @escaping (String) -> Void,
        onFinal: @escaping (String) -> Void,
        onError: @escaping (Error) -> Void
    ) {
        // Жёстко используем русскую локаль для максимальной надёжности
        start(
            locale: preferredLocales[0], // ru-RU
            onPartial: onPartial,
            onFinal: onFinal,
            onError: onError
        )
    }
    
    /// Начинает распознавание речи с конкретной локалью
    func start(
        locale: Locale,
        onPartial: @escaping (String) -> Void,
        onFinal: @escaping (String) -> Void,
        onError: @escaping (Error) -> Void
    ) {
        guard !isListening else {
            print("🎤 SpeechService: Already listening")
            return
        }
        
        guard permissionStatus == .authorized else {
            onError(SpeechError.permissionDenied)
            return
        }
        
        self.onPartial = onPartial
        self.onFinal = onFinal
        self.onError = onError
        
        // Сбрасываем защиту от дублирования
        self.hasFiredFinal = false
        self.lastFinalText = ""
        
        // Выбираем лучший доступный recognizer
        let selectedLocale = selectBestLocale(preferred: locale)
        speechRecognizer = SFSpeechRecognizer(locale: selectedLocale)
        
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            print("🎤 SpeechService: Recognizer unavailable for \(selectedLocale.identifier)")
            onError(SpeechError.recognizerUnavailable)
            return
        }
        
        print("🎤 SpeechService: Using locale \(selectedLocale.identifier)")
        
        do {
            try startAudioEngine()
            isListening = true
            print("🎤 SpeechService: Started listening")
        } catch {
            onError(error)
            print("🎤 SpeechService: Failed to start - \(error.localizedDescription)")
        }
    }
    
    /// Выбирает лучшую доступную локаль
    private func selectBestLocale(preferred: Locale) -> Locale {
        // Сначала проверяем предпочитаемую
        if SFSpeechRecognizer(locale: preferred)?.isAvailable == true {
            return preferred
        }
        
        // Затем пробуем все поддерживаемые по порядку приоритета
        for locale in preferredLocales {
            if SFSpeechRecognizer(locale: locale)?.isAvailable == true {
                print("🎤 SpeechService: Fallback to \(locale.identifier)")
                return locale
            }
        }
        
        // Последний fallback - система
        print("🎤 SpeechService: Using system locale as final fallback")
        return Locale.current
    }
    
    /// Останавливает распознавание речи
    func stop() {
        guard isListening else { return }
        
        stopInternal()
        print("🎤 SpeechService: Stopped listening")
    }
    
    /// Внутренний stop без логов (для вызова из onFinal)
    private func stopInternal() {
        audioEngine.stop()
        if audioEngine.inputNode.numberOfInputs > 0 {
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        recognitionTask?.cancel()
        recognitionTask = nil
        
        isListening = false
    }
    
    // MARK: - Private Methods
    
    private func startAudioEngine() throws {
        // Отменяем предыдущую задачу если есть
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Настраиваем аудио сессию
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        // Создаём запрос распознавания
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let recognitionRequest = recognitionRequest else {
            throw SpeechError.requestCreationFailed
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // ✅ FIX: Принудительно используем on-device распознавание
        // Это гарантирует русскую локаль без серверных подмен
        if let recognizer = speechRecognizer, recognizer.supportsOnDeviceRecognition {
            recognitionRequest.requiresOnDeviceRecognition = true
            print("🎤 SpeechService: ✅ On-device recognition ENABLED (forced)")
        } else {
            // Fallback: устройство не поддерживает on-device
            recognitionRequest.requiresOnDeviceRecognition = false
            print("🎤 SpeechService: ⚠️ On-device not supported, using server-side")
        }
        
        // Создаём задачу распознавания
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor in
                self?.handleRecognitionResult(result: result, error: error)
            }
        }
        
        // Настраиваем входной узел
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
    }
    
    private func handleRecognitionResult(result: SFSpeechRecognitionResult?, error: Error?) {
        if let error = error {
            // Игнорируем ошибку отмены и некоторые системные ошибки
            let nsError = error as NSError
            if nsError.code != 1 && nsError.code != 216 && nsError.code != 203 {
                onError?(error)
            }
            stopInternal()
            return
        }
        
        guard let result = result else { return }
        
        let transcription = result.bestTranscription.formattedString
        
        if result.isFinal {
            // Проверяем что текст не пустой и не мусор
            let canonicalText = EffectResolver.canonicalKey(transcription)
            guard !canonicalText.isEmpty, transcription.count > 1 else {
                print("🎤 SpeechService: Ignoring empty/invalid final: '\(transcription)'")
                stopInternal()
                return
            }
            
            // Защита от двойного вызова onFinal с тем же текстом
            guard !hasFiredFinal, transcription != lastFinalText else {
                print("🎤 SpeechService: Skipping duplicate final: '\(transcription)'")
                return
            }
            
            hasFiredFinal = true
            lastFinalText = transcription
            
            print("FINAL: '\(transcription)'")
            
            // Сначала останавливаем, потом вызываем callback
            stopInternal()
            onFinal?(transcription)
        } else {
            onPartial?(transcription)
        }
    }
}

// MARK: - Errors

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
