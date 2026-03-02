import SwiftUI

/// Voice Composer - голосовое и текстовое управление эффектами
struct VoiceComposerView: View {
    
    // MARK: - Dependencies
    
    @ObservedObject var cameraManager: CameraManager
    @ObservedObject var shaderManager: ShaderManager
    @ObservedObject var mediaRecorder: MediaRecorder
    @ObservedObject var framePipeline: FramePipeline
    
    @StateObject private var speechService = SpeechService()
    
    // MARK: - State
    
    @State private var recognizedText: String = ""
    @State private var statusMessage: String = ""
    @State private var status: Status = .idle
    @State private var showPermissionAlert: Bool = false
    @State private var inputMode: InputMode = .voice
    @State private var lastProcessedText: String = ""  // Для debounce
    @State private var isProcessingCommand: Bool = false
    @State private var dismissTask: Task<Void, Never>?
    
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isTextFieldFocused: Bool
    
    enum InputMode: String, CaseIterable {
        case voice = "Голос"
        case text = "Текст"
    }
    
    enum Status {
        case idle
        case listening
        case processing
        case success
        case error
        
        var color: Color {
            switch self {
            case .idle: return .gray
            case .listening: return .red
            case .processing: return .orange
            case .success: return .green
            case .error: return .red
            }
        }
        
        var icon: String {
            switch self {
            case .idle: return "mic"
            case .listening: return "mic.fill"
            case .processing: return "gear"
            case .success: return "checkmark.circle"
            case .error: return "xmark.circle"
            }
        }
    }
    
    // MARK: - Example Commands
    
    private let exampleCommands = [
        "создай шейдер замиксуй комик и нейро",
        "добавь блюр",
        "интенсивность 70%",
        "комик",
        "начни запись"
    ]
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
                .onTapGesture {
                    isTextFieldFocused = false
                }
            
            VStack(spacing: 16) {
                modePicker
                statusIndicator
                inputArea
                exampleChips
                controlButtons
                helpSection
                Spacer()
            }
            .padding()
        }
        .navigationTitle(NSLocalizedString("voice_composer_title", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(NSLocalizedString("close", comment: "")) {
                    cleanup()
                    dismiss()
                }
                .foregroundColor(.white)
            }
            
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    isTextFieldFocused = false
                }
            }
        }
        .preferredColorScheme(.dark)
        .alert(NSLocalizedString("permission_required_title", comment: ""), isPresented: $showPermissionAlert) {
            Button(NSLocalizedString("open_settings", comment: "")) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button(NSLocalizedString("cancel", comment: ""), role: .cancel) {}
        } message: {
            Text(NSLocalizedString("permission_required_message", comment: ""))
        }
        .onDisappear {
            cleanup()
        }
    }
    
    // MARK: - Mode Picker
    
    private var modePicker: some View {
        Picker("Input Mode", selection: $inputMode) {
            ForEach(InputMode.allCases, id: \.self) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: inputMode) { _, newMode in
            if newMode == .text {
                speechService.stop()
                status = .idle
            }
            isTextFieldFocused = false
        }
    }
    
    // MARK: - Status Indicator
    
    private var statusIndicator: some View {
        HStack(spacing: 12) {
            Image(systemName: status.icon)
                .font(.title2)
                .foregroundColor(status.color)
                .symbolEffect(.pulse, isActive: status == .listening)
            
            Text(statusMessage.isEmpty ? (inputMode == .voice ? "Нажмите 🎤" : "Введите команду") : statusMessage)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(4)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
    
    // MARK: - Input Area
    
    private var inputArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(inputMode == .voice ? "Распознанный текст:" : "Введите команду:")
                .font(.caption)
                .foregroundColor(.gray)
            
            if inputMode == .voice {
                Text(recognizedText.isEmpty ? "..." : recognizedText)
                    .font(.body)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: 60, alignment: .topLeading)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.1))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(status == .listening ? Color.red : Color.white.opacity(0.2), lineWidth: 1)
                    )
            } else {
                TextField("Например: создай шейдер замиксуй комик и нейро", text: $recognizedText)
                    .font(.body)
                    .foregroundColor(.white)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.1))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isTextFieldFocused ? Color.blue : Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .focused($isTextFieldFocused)
                    .submitLabel(.done)
                    .onSubmit {
                        applyCommand()
                    }
            }
        }
    }
    
    // MARK: - Example Chips
    
    private var exampleChips: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Примеры:")
                .font(.caption)
                .foregroundColor(.gray)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(exampleCommands, id: \.self) { command in
                        Button {
                            recognizedText = command
                        } label: {
                            Text(command)
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(.ultraThinMaterial))
                                .foregroundColor(.white)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Control Buttons
    
    private var controlButtons: some View {
        HStack(spacing: 16) {
            if inputMode == .voice {
                Button {
                    toggleListening()
                } label: {
                    HStack {
                        Image(systemName: speechService.isListening ? "stop.fill" : "mic.fill")
                        Text(speechService.isListening ? "Стоп" : "Говорить")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(speechService.isListening ? Color.red : Color.blue)
                    )
                }
            } else {
                Button {
                    applyCommand()
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Применить")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(recognizedText.isEmpty ? Color.gray : Color.green)
                    )
                }
                .disabled(recognizedText.isEmpty)
            }
        }
    }
    
    // MARK: - Help Section
    
    private var helpSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Команды:")
                .font(.caption.bold())
                .foregroundColor(.gray)
            
            VStack(alignment: .leading, spacing: 6) {
                helpItem(icon: "wand.and.stars", text: "создай шейдер замиксуй комик и нейро")
                helpItem(icon: "square.stack.3d.up", text: "добавь блюр / добавь зерно")
                helpItem(icon: "slider.horizontal.3", text: "интенсивность 50%")
                helpItem(icon: "sparkles", text: "комик / нейро / туман")
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
    }
    
    private func helpItem(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
    }
    
    // MARK: - Actions
    
    private func cleanup() {
        dismissTask?.cancel()
        speechService.stop()
        isTextFieldFocused = false
    }
    
    private func toggleListening() {
        if speechService.isListening {
            speechService.stop()
            status = .idle
            statusMessage = ""
        } else {
            startListening()
        }
    }
    
    private func startListening() {
        Task {
            let granted = await speechService.requestPermissions()
            
            if !granted {
                showPermissionAlert = true
                return
            }
            
            status = .listening
            statusMessage = "Слушаю..."
            recognizedText = ""
            lastProcessedText = ""
            isProcessingCommand = false
            
            // Жёстко используем русскую локаль
            speechService.start(
                onPartial: { text in
                    recognizedText = text
                },
                onFinal: { text in
                    recognizedText = text
                    print("FINAL: '\(text)'")
                    // Voice mode: ВСЕГДА выполняем команду если есть валидный текст
                    if inputMode == .voice {
                        executeVoiceCommand(text)
                    }
                },
                onError: { error in
                    // Не показываем ошибку как "красный крест" если это просто конец речи
                    if status == .listening {
                        status = .idle
                        statusMessage = ""
                    }
                }
            )
        }
    }
    
    /// Выполняет команду в Voice mode (с автозакрытием при успехе)
    private func executeVoiceCommand(_ text: String) {
        // Проверяем валидность текста через canonicalKey
        let canonicalText = EffectResolver.canonicalKey(text)
        guard !canonicalText.isEmpty else {
            print("🎤 VoiceComposer: Ignoring empty canonical text for '\(text)'")
            return
        }
        
        // Debounce: сравниваем канонические ключи
        guard canonicalText != EffectResolver.canonicalKey(lastProcessedText), !isProcessingCommand else {
            print("🎤 VoiceComposer: Skipping duplicate canonical text: '\(canonicalText)'")
            return
        }
        lastProcessedText = text
        isProcessingCommand = true
        
        status = .processing
        statusMessage = "Выполняю..."
        
        let command = VoiceCommandParser.parse(text)
        print("PARSED: \(command)")
        
        let result = VoiceCommandExecutor.execute(
            command,
            cameraManager: cameraManager,
            shaderManager: shaderManager,
            mediaRecorder: mediaRecorder,
            framePipeline: framePipeline
        )
        
        print("EXEC: \(result.status), \(result.message)")
        
        handleExecResult(result)
    }
    
    /// Выполняет команду в Text mode (закрывает только при успехе)
    private func applyCommand() {
        guard !recognizedText.isEmpty else { return }
        
        isTextFieldFocused = false
        status = .processing
        statusMessage = "Выполняю..."
        
        let command = VoiceCommandParser.parse(recognizedText)
        print("🎤 VoiceComposer: Text command - \(command)")
        
        let result = VoiceCommandExecutor.execute(
            command,
            cameraManager: cameraManager,
            shaderManager: shaderManager,
            mediaRecorder: mediaRecorder,
            framePipeline: framePipeline
        )
        
        print("🎤 VoiceComposer: ExecResult - status=\(result.status), message=\(result.message)")
        
        handleExecResult(result)
    }
    
    /// Обрабатывает результат выполнения команды
    private func handleExecResult(_ result: ExecResult) {
        statusMessage = result.message
        
        switch result.status {
        case .success:
            status = .success
            // Auto-close после небольшой задержки
            dismissTask = Task {
                try? await Task.sleep(nanoseconds: 250_000_000) // 0.25 сек
                if !Task.isCancelled {
                    cleanup()
                    dismiss()
                }
            }
            
        case .error:
            status = .error
            isProcessingCommand = false
            // НЕ закрываем — пользователь может попробовать снова
            
        case .blocked:
            status = .error
            isProcessingCommand = false
            // НЕ закрываем
            
        case .unknown:
            status = .error
            isProcessingCommand = false
            // НЕ закрываем — показываем подсказки
        }
    }
}

// MARK: - Preview

#Preview {
    VoiceComposerView(
        cameraManager: CameraManager(),
        shaderManager: ShaderManager.shared,
        mediaRecorder: MediaRecorder(),
        framePipeline: FramePipeline.shared
    )
}
