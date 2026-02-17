import SwiftUI

/// Voice Composer - голосовое управление эффектами
struct VoiceComposerView: View {
    
    // MARK: - Dependencies
    
    @ObservedObject var cameraManager: CameraManager
    @ObservedObject var shaderManager: ShaderManager
    @ObservedObject var mediaRecorder: MediaRecorder
    @ObservedObject var framePipeline: FramePipeline
    
    @StateObject private var speechService = SpeechService()
    
    // MARK: - State
    
    @State private var recognizedText: String = ""
    @State private var statusMessage: String = "Нажмите 🎤 чтобы начать"
    @State private var status: Status = .idle
    @State private var showPermissionAlert: Bool = false
    
    @Environment(\.dismiss) private var dismiss
    
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
        "комик",
        "нейро",
        "туман",
        "интенсивность 70%",
        "зум 2",
        "начни запись",
        "стоп"
    ]
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // Status indicator
                    statusIndicator
                    
                    // Recognized text
                    textEditor
                    
                    // Example chips
                    exampleChips
                    
                    // Control buttons
                    controlButtons
                    
                    // Help section
                    helpSection
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Voice Composer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Закрыть") {
                        speechService.stop()
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
        .alert("Требуется разрешение", isPresented: $showPermissionAlert) {
            Button("Открыть настройки") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Для голосового управления необходим доступ к микрофону и распознаванию речи")
        }
    }
    
    // MARK: - Status Indicator
    
    private var statusIndicator: some View {
        HStack(spacing: 12) {
            Image(systemName: status.icon)
                .font(.title2)
                .foregroundColor(status.color)
                .symbolEffect(.pulse, isActive: status == .listening)
            
            Text(statusMessage)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(3)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
    
    // MARK: - Text Editor
    
    private var textEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Распознанный текст:")
                .font(.caption)
                .foregroundColor(.gray)
            
            TextEditor(text: $recognizedText)
                .font(.body)
                .foregroundColor(.white)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 80, maxHeight: 120)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(status == .listening ? Color.red : Color.white.opacity(0.2), lineWidth: 1)
                )
        }
    }
    
    // MARK: - Example Chips
    
    private var exampleChips: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Примеры команд:")
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
                                .background(
                                    Capsule()
                                        .fill(.ultraThinMaterial)
                                )
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
            // Mic button
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
            
            // Apply button
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
    
    // MARK: - Help Section
    
    private var helpSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Что я умею:")
                .font(.caption.bold())
                .foregroundColor(.gray)
            
            VStack(alignment: .leading, spacing: 6) {
                helpItem(icon: "wand.and.stars", text: "Эффекты: комик, нейро, туман, контур")
                helpItem(icon: "slider.horizontal.3", text: "Интенсивность: 50%, сильнее, слабее")
                helpItem(icon: "record.circle", text: "Запись: начни запись, стоп")
                helpItem(icon: "plus.magnifyingglass", text: "Зум: 0.5, 1, 2")
                helpItem(icon: "camera.rotate", text: "Камера: переключи камеру")
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
    
    private func toggleListening() {
        if speechService.isListening {
            speechService.stop()
            status = .idle
            statusMessage = "Готово к применению"
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
            
            speechService.start(
                locale: Locale(identifier: "ru-RU"),
                onPartial: { text in
                    recognizedText = text
                },
                onFinal: { text in
                    recognizedText = text
                    status = .idle
                    statusMessage = "Готово к применению"
                },
                onError: { error in
                    status = .error
                    statusMessage = "Ошибка: \(error.localizedDescription)"
                }
            )
        }
    }
    
    private func applyCommand() {
        guard !recognizedText.isEmpty else { return }
        
        status = .processing
        statusMessage = "Выполняю..."
        
        let command = VoiceCommandParser.parse(recognizedText)
        
        let result = VoiceCommandExecutor.execute(
            command,
            cameraManager: cameraManager,
            shaderManager: shaderManager,
            mediaRecorder: mediaRecorder,
            framePipeline: framePipeline
        )
        
        // Определяем статус по результату
        if result.hasPrefix("✅") || result.hasPrefix("🔴") || result.hasPrefix("⏹️") || result.hasPrefix("📸") {
            status = .success
        } else if result.hasPrefix("❌") || result.hasPrefix("⚠️") {
            status = .error
        } else {
            status = .idle
        }
        
        statusMessage = result
        
        // Сбрасываем статус через 3 секунды
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            if status != .listening {
                status = .idle
                statusMessage = "Нажмите 🎤 чтобы начать"
            }
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
