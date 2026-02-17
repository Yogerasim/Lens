import Foundation

/// Исполнитель голосовых команд
struct VoiceCommandExecutor {
    
    /// Выполняет команду и возвращает человекочитаемый статус
    @MainActor
    static func execute(
        _ command: VoiceCommand,
        cameraManager: CameraManager,
        shaderManager: ShaderManager,
        mediaRecorder: MediaRecorder,
        framePipeline: FramePipeline = .shared
    ) -> String {
        
        print("🎙️ VoiceCommandExecutor: Executing command - \(command)")
        
        switch command {
            
        // MARK: - Select Filter
        case .selectFilter(let filter):
            // Проверяем доступность фильтра
            let isFront = cameraManager.isFrontCamera
            let isRecording = framePipeline.isRecording
            let recordingFamily = framePipeline.recordingFilterFamily
            
            // Проверка: depth фильтр на фронталке
            if filter.needsDepth && isFront {
                return "❌ \(filter.name) недоступен на фронтальной камере"
            }
            
            // Проверка: смена семейства во время записи
            if isRecording, let family = recordingFamily {
                let filterFamily: FilterFamily = filter.needsDepth ? .depth : .nonDepth
                if filterFamily != family {
                    return "❌ Во время записи нельзя переключиться на \(filter.name)"
                }
            }
            
            // Применяем фильтр
            shaderManager.selectShader(by: filter.shaderName)
            return "✅ Применён: \(filter.name)"
            
        // MARK: - Intensity
        case .setIntensity(let value):
            let clampedValue = max(0, min(1, value))
            framePipeline.setTargetIntensity(clampedValue, reason: "voice command")
            let percent = Int(clampedValue * 100)
            return "✅ Интенсивность: \(percent)%"
            
        case .increaseIntensity:
            let current = framePipeline.targetIntensity
            let newValue = min(1.0, current + 0.1)
            framePipeline.setTargetIntensity(newValue, reason: "voice increase")
            let percent = Int(newValue * 100)
            return "✅ Интенсивность: \(percent)%"
            
        case .decreaseIntensity:
            let current = framePipeline.targetIntensity
            let newValue = max(0.0, current - 0.1)
            framePipeline.setTargetIntensity(newValue, reason: "voice decrease")
            let percent = Int(newValue * 100)
            return "✅ Интенсивность: \(percent)%"
            
        // MARK: - Recording
        case .startRecording:
            if mediaRecorder.isRecording {
                return "⚠️ Запись уже идёт"
            }
            framePipeline.startRecording()
            mediaRecorder.startRecording()
            return "🔴 Запись начата"
            
        case .stopRecording:
            if !mediaRecorder.isRecording {
                return "⚠️ Запись не идёт"
            }
            framePipeline.stopRecording()
            mediaRecorder.stopRecording()
            return "⏹️ Запись остановлена"
            
        // MARK: - Zoom
        case .setZoom(let preset):
            // Проверка: в depth режиме доступен только x1
            if cameraManager.isDepthEnabled && preset != .wide {
                return "❌ В режиме глубины доступен только зум 1×"
            }
            
            cameraManager.zoom(to: preset)
            
            switch preset {
            case .ultraWide:
                return "✅ Зум: 0.5×"
            case .wide:
                return "✅ Зум: 1×"
            case .telephoto:
                return "✅ Зум: 2×"
            }
            
        // MARK: - Switch Camera
        case .switchCamera:
            // Проверка: во время записи нельзя
            if framePipeline.isRecording {
                return "❌ Нельзя переключить камеру во время записи"
            }
            
            // Проверка: в depth режиме нельзя
            if cameraManager.isDepthEnabled {
                return "❌ Нельзя переключить камеру в режиме глубины"
            }
            
            cameraManager.switchCamera()
            let cameraName = cameraManager.isFrontCamera ? "Фронтальная" : "Основная"
            return "✅ Камера: \(cameraName)"
            
        // MARK: - Take Photo
        case .takePhoto:
            mediaRecorder.takePhoto()
            return "📸 Фото сделано"
            
        // MARK: - Unknown
        case .unknown(let suggestions):
            let suggestionText = suggestions.prefix(3).joined(separator: "\n")
            return "❓ Не понял команду.\n\(suggestionText)"
        }
    }
}
