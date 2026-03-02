import Foundation

/// Исполнитель голосовых команд
struct VoiceCommandExecutor {
    
    /// Выполняет команду и возвращает результат с подробным статусом
    @MainActor
    static func execute(
        _ command: VoiceCommand,
        cameraManager: CameraManager,
        shaderManager: ShaderManager,
        mediaRecorder: MediaRecorder,
        framePipeline: FramePipeline = .shared
    ) -> ExecResult {
        
        print("🎙️ VoiceCommandExecutor: Executing command - \(command)")
        
        switch command {
            
        // MARK: - Select Filter
        case .selectFilter(let filter):
            let isFront = cameraManager.isFrontCamera
            let isRecording = framePipeline.isRecording
            let recordingFamily = framePipeline.recordingFilterFamily
            
            if filter.needsDepth && isFront {
                return .blocked("⛔️ \(filter.name) недоступен на фронтальной камере")
            }
            
            if isRecording, let family = recordingFamily {
                let filterFamily: FilterFamily = filter.needsDepth ? .depth : .nonDepth
                if filterFamily != family {
                    return .blocked("⛔️ Во время записи нельзя переключиться на \(filter.name)")
                }
            }
            
            shaderManager.selectShader(by: filter.shaderName)
            return .success("✅ Применён: \(filter.name)", appliedEffect: true)
            
        // MARK: - Intensity
        case .setIntensity(let value):
            let clampedValue = max(0, min(1, value))
            framePipeline.setTargetIntensity(clampedValue, reason: "voice command")
            let percent = Int(clampedValue * 100)
            return .success("✅ Интенсивность: \(percent)%")
            
        case .increaseIntensity:
            let current = framePipeline.targetIntensity
            let newValue = min(1.0, current + 0.1)
            framePipeline.setTargetIntensity(newValue, reason: "voice increase")
            let percent = Int(newValue * 100)
            return .success("✅ Интенсивность: \(percent)%")
            
        case .decreaseIntensity:
            let current = framePipeline.targetIntensity
            let newValue = max(0.0, current - 0.1)
            framePipeline.setTargetIntensity(newValue, reason: "voice decrease")
            let percent = Int(newValue * 100)
            return .success("✅ Интенсивность: \(percent)%")
            
        // MARK: - Recording
        case .startRecording:
            if mediaRecorder.isRecording {
                return .blocked("⚠️ Запись уже идёт")
            }
            framePipeline.startRecording()
            mediaRecorder.startRecording()
            return .success("🔴 Запись начата")
            
        case .stopRecording:
            if !mediaRecorder.isRecording {
                return .blocked("⚠️ Запись не идёт")
            }
            framePipeline.stopRecording()
            mediaRecorder.stopRecording()
            return .success("⏹️ Запись остановлена")
            
        // MARK: - Zoom
        case .setZoom(let preset):
            if cameraManager.isDepthEnabled && preset != .wide {
                return .blocked("⛔️ В режиме глубины доступен только зум 1×")
            }
            
            cameraManager.zoom(to: preset)
            
            switch preset {
            case .ultraWide: return .success("✅ Зум: 0.5×")
            case .wide: return .success("✅ Зум: 1×")
            case .telephoto: return .success("✅ Зум: 2×")
            }
            
        // MARK: - Switch Camera
        case .switchCamera:
            if framePipeline.isRecording {
                return .blocked("⛔️ Нельзя переключить камеру во время записи")
            }
            
            if cameraManager.isDepthEnabled {
                return .blocked("⛔️ Нельзя переключить камеру в режиме глубины")
            }
            
            cameraManager.switchCamera()
            let cameraName = cameraManager.isFrontCamera ? "Фронтальная" : "Основная"
            return .success("✅ Камера: \(cameraName)")
            
        // MARK: - Take Photo
        case .takePhoto:
            mediaRecorder.takePhoto()
            return .success("📸 Фото сделано")
            
        // MARK: - Set Filter With Intensity
        case .setFilterWithIntensity(let effectName, let percent):
            let intensity = Float(percent) / 100.0
            
            // Резолвим эффект через EffectResolver
            guard let source = EffectResolver.resolveAnyEffect(name: effectName) else {
                return .error("❌ Эффект '\(effectName)' не найден")
            }
            
            // Проверяем depth на фронталке
            if source.needsDepth && cameraManager.isFrontCamera {
                return .blocked("⛔️ \(source.displayName) недоступен на фронтальной камере")
            }
            
            // Проверяем блокировку при записи
            let isRecording = framePipeline.isRecording
            let recordingFamily = framePipeline.recordingFilterFamily
            
            if isRecording, let family = recordingFamily {
                let effectFamily: FilterFamily = source.needsDepth ? .depth : .nonDepth
                if effectFamily != family {
                    return .blocked("⛔️ Во время записи нельзя переключиться на \(source.displayName)")
                }
            }
            
            // Применяем эффект
            switch source {
            case .builtIn(let filter):
                shaderManager.selectShader(by: filter.shaderName)
                
            case .custom(let graph):
                let graphSession = GraphSessionController.shared
                _ = graphSession.selectGraph(graph)
                activateCustomGraphMode(shaderManager: shaderManager)
            }
            
            // Устанавливаем интенсивность
            framePipeline.setTargetIntensity(intensity, reason: "voice command with intensity")
            
            return .success("✅ \(source.displayName): \(percent)%", appliedEffect: true)
            
        // MARK: - Add Node (low-level)
        case .addNode(let nodeType):
            let graphSession = GraphSessionController.shared
            
            if nodeType.needsDepth && cameraManager.isFrontCamera {
                return .blocked("⛔️ \(nodeType.displayName) недоступен на фронтальной камере")
            }
            
            let result = graphSession.addNode(nodeType)
            
            if result.success {
                activateCustomGraphMode(shaderManager: shaderManager)
                return .success(result.message, appliedEffect: true, createdGraph: true)
            } else {
                return .error(result.message)
            }
            
        case .removeLastNode:
            let graphSession = GraphSessionController.shared
            let result = graphSession.removeLastNode()
            
            if !graphSession.isCustomGraphActive {
                deactivateCustomGraphMode(shaderManager: shaderManager)
            }
            
            return result.success ? .success(result.message, createdGraph: true) : .error(result.message)
            
        case .clearGraph:
            let graphSession = GraphSessionController.shared
            let result = graphSession.clearGraph()
            deactivateCustomGraphMode(shaderManager: shaderManager)
            return .success(result.message, createdGraph: true)
            
        case .saveGraph(let name):
            let graphSession = GraphSessionController.shared
            let result = graphSession.saveGraph(name: name)
            return result.success ? .success(result.message, createdGraph: true) : .error(result.message)
            
        // MARK: - Create Effect (high-level recipe)
        case .createEffect(let recipe):
            return executeCreateEffect(recipe, shaderManager: shaderManager, cameraManager: cameraManager)
            
        case .remixEffect(let base, let recipe):
            var modifiedRecipe = recipe
            modifiedRecipe.mixA = base
            return executeCreateEffect(modifiedRecipe, shaderManager: shaderManager, cameraManager: cameraManager)
            
        case .applyEffect(let name):
            let graphSession = GraphSessionController.shared
            let result = graphSession.selectGraph(name: name)
            
            if result.success {
                activateCustomGraphMode(shaderManager: shaderManager)
                return .success("✅ Применён: \(name)", appliedEffect: true)
            } else {
                return .error(result.message)
            }
            
        // MARK: - Unknown
        case .unknown(let suggestions):
            let suggestionText = suggestions.prefix(3).joined(separator: "\n")
            return .unknown("❓ Не понял команду.\n\(suggestionText)")
        }
    }
    
    // MARK: - Create Effect from Recipe
    
    @MainActor
    private static func executeCreateEffect(
        _ recipe: EffectRecipe,
        shaderManager: ShaderManager,
        cameraManager: CameraManager
    ) -> ExecResult {
        let graphSession = GraphSessionController.shared
        let store = EffectGraphStore.shared
        
        // 1. Создаём новый draft
        graphSession.newDraft()
        
        // 2. Устанавливаем микс если есть, используя EffectResolver
        if let mixA = recipe.mixA, let mixB = recipe.mixB {
            // Резолвим имена эффектов через EffectResolver
            guard let sourceA = EffectResolver.resolveAnyEffect(name: mixA) else {
                return .error("❌ Эффект '\(mixA)' не найден")
            }
            guard let sourceB = EffectResolver.resolveAnyEffect(name: mixB) else {
                return .error("❌ Эффект '\(mixB)' не найден")
            }
            
            // Проверяем depth на фронталке
            if (sourceA.needsDepth || sourceB.needsDepth) && cameraManager.isFrontCamera {
                let problematicEffect = sourceA.needsDepth ? sourceA.displayName : sourceB.displayName
                return .blocked("⛔️ \(problematicEffect) недоступен на фронтальной камере")
            }
            
            // Используем displayName для красивого отображения в UI
            let ratioA = recipe.ratioA ?? 0.5
            let ratioB = recipe.ratioB ?? 0.5
            let mixResult = graphSession.setMix(
                effectA: sourceA.displayName,
                effectB: sourceB.displayName,
                ratioA: ratioA,
                ratioB: ratioB
            )
            if !mixResult.success {
                return .error(mixResult.message)
            }
        }
        
        // 3. Добавляем узлы
        for nodeType in recipe.nodesToAdd {
            // Проверка depth на фронталке
            if nodeType.needsDepth && cameraManager.isFrontCamera {
                return .blocked("⛔️ \(nodeType.displayName) недоступен на фронтальной камере")
            }
            
            let nodeResult = graphSession.addNode(nodeType)
            if !nodeResult.success {
                return .error(nodeResult.message)
            }
        }
        
        // 4. Генерируем/используем имя
        var finalName = recipe.name
        if finalName == nil || finalName!.isEmpty {
            finalName = store.generateUniqueName(base: "Effect")
        } else {
            finalName = store.ensureUniqueName(finalName!)
        }
        
        // 5. Сохраняем
        let saveResult = graphSession.saveGraph(name: finalName)
        if !saveResult.success {
            return .error(saveResult.message)
        }
        
        // 6. Активируем Custom Graph
        activateCustomGraphMode(shaderManager: shaderManager)
        
        print("🎉 VoiceCommandExecutor: Created effect '\(finalName!)' with mix=\(recipe.mixA ?? "nil")+\(recipe.mixB ?? "nil"), nodes=\(recipe.nodesToAdd.map { $0.rawValue })")
        
        return .success("✅ Создан: \(finalName!)", appliedEffect: true, createdGraph: true)
    }
    
    // MARK: - Private Helpers
    
    @MainActor
    private static func activateCustomGraphMode(shaderManager: ShaderManager) {
        if let customFilter = FilterLibrary.shared.filters.first(where: { $0.shaderName == "fragment_universalgraph" }) {
            shaderManager.selectShader(by: customFilter.shaderName)
            print("🎨 VoiceCommandExecutor: Activated Custom Graph mode")
        }
    }
    
    @MainActor
    private static func deactivateCustomGraphMode(shaderManager: ShaderManager) {
        if let firstFilter = FilterLibrary.shared.filters.first(where: { $0.shaderName != "fragment_universalgraph" }) {
            shaderManager.selectShader(by: firstFilter.shaderName)
            print("🎨 VoiceCommandExecutor: Deactivated Custom Graph mode")
        }
    }
}
