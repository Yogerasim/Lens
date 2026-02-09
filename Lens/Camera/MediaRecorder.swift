import AVFoundation
import Photos
import UIKit
import Combine

// MARK: - Capture Mode
enum CaptureMode: String, CaseIterable {
    case photo = "ФОТО"
    case video = "ВИДЕО"
}

// MARK: - Video Recorder
final class MediaRecorder: NSObject, ObservableObject {
    
    // MARK: - Published
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var captureMode: CaptureMode = .video
    
    // MARK: - Private - Video
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    
    // MARK: - Private - State
    private var videoURL: URL?
    private var startTime: CMTime?
    private var audioStartTime: CMTime?
    private var lastVideoTime: CMTime = .zero
    private var recordingTimer: Timer?
    private var sessionStarted = false
    
    private let writerQueue = DispatchQueue(label: "media.recorder.queue", qos: .userInitiated)
    
    // MARK: - Video Settings (динамические на основе реального размера камеры)
    private var videoWidth: Int {
        DeviceCapabilities.currentCameraWidth
    }
    private var videoHeight: Int {
        DeviceCapabilities.currentCameraHeight
    }
    
    // MARK: - Photo/Video Capture (обработанный кадр с шейдером)
    private var lastRenderedBuffer: CVPixelBuffer?
    
    // MARK: - Public API
    
    /// Сохранить последний обработанный кадр для фото
    func setLastRenderedFrame(_ pixelBuffer: CVPixelBuffer) {
        lastRenderedBuffer = pixelBuffer
    }
    
    func startRecording() {
        guard !isRecording else { return }
        
        writerQueue.async {
            self.setupAssetWriter()
            
            DispatchQueue.main.async {
                self.isRecording = true
                self.recordingDuration = 0
                self.startRecordingTimer()
            }
        }
    }
    
    func stopRecording() {
        guard isRecording else { return }
        
        DispatchQueue.main.async {
            self.isRecording = false
            self.stopRecordingTimer()
        }
        
        writerQueue.async {
            self.finishRecording()
        }
    }
    
    /// Записать видео кадр (обработанный с шейдером)
    func appendVideoFrame(_ pixelBuffer: CVPixelBuffer, at time: CMTime) {
        // Сохраняем для фото
        lastRenderedBuffer = pixelBuffer
        
        guard isRecording else { return }
        
        writerQueue.async {
            guard let writer = self.assetWriter,
                  writer.status == .writing,
                  let adaptor = self.pixelBufferAdaptor,
                  let input = self.videoInput,
                  input.isReadyForMoreMediaData else { return }
            
            // Инициализируем сессию при первом кадре
            if !self.sessionStarted {
                self.startTime = time
                writer.startSession(atSourceTime: .zero)
                self.sessionStarted = true
                print("✅ Recording session started")
            }
            
            guard let start = self.startTime else { return }
            let presentationTime = CMTimeSubtract(time, start)
            
            // Проверяем что время идёт вперёд
            if presentationTime > self.lastVideoTime || self.lastVideoTime == .zero {
                if adaptor.append(pixelBuffer, withPresentationTime: presentationTime) {
                    self.lastVideoTime = presentationTime
                }
            }
        }
    }
    
    /// Записать аудио сэмпл
    func appendAudioSample(_ sampleBuffer: CMSampleBuffer) {
        guard isRecording else { return }
        
        writerQueue.async {
            guard let writer = self.assetWriter,
                  writer.status == .writing,
                  self.sessionStarted,
                  let input = self.audioInput,
                  input.isReadyForMoreMediaData else { return }
            
            // Корректируем время аудио относительно старта видео
            guard let startTime = self.startTime else { return }
            
            let audioTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            let adjustedTime = CMTimeSubtract(audioTime, startTime)
            
            // Пропускаем аудио до начала видео
            if adjustedTime.seconds < 0 { return }
            
            // Создаём копию сэмпла с корректным временем
            var timingInfo = CMSampleTimingInfo(
                duration: CMSampleBufferGetDuration(sampleBuffer),
                presentationTimeStamp: adjustedTime,
                decodeTimeStamp: .invalid
            )
            
            var adjustedBuffer: CMSampleBuffer?
            CMSampleBufferCreateCopyWithNewTiming(
                allocator: kCFAllocatorDefault,
                sampleBuffer: sampleBuffer,
                sampleTimingEntryCount: 1,
                sampleTimingArray: &timingInfo,
                sampleBufferOut: &adjustedBuffer
            )
            
            if let buffer = adjustedBuffer {
                input.append(buffer)
            }
        }
    }
    
    func takePhoto() {
        guard let buffer = lastRenderedBuffer else {
            print("❌ No rendered frame available for photo")
            return
        }
        
        writerQueue.async {
            self.savePhotoToLibrary(pixelBuffer: buffer)
        }
    }
    
    // MARK: - Private - Setup
    
    private func setupAssetWriter() {
        let fileName = "Lens_\(Date().timeIntervalSince1970).mp4"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        // Удаляем старый файл если есть
        try? FileManager.default.removeItem(at: tempURL)
        
        do {
            assetWriter = try AVAssetWriter(url: tempURL, fileType: .mp4)
            videoURL = tempURL
            
            // Video Input
            let videoSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: videoWidth,
                AVVideoHeightKey: videoHeight,
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: 10_000_000,
                    AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                    AVVideoMaxKeyFrameIntervalKey: 30
                ]
            ]
            
            videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            videoInput?.expectsMediaDataInRealTime = true
            
            let sourcePixelBufferAttributes: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: videoWidth,
                kCVPixelBufferHeightKey as String: videoHeight
            ]
            
            pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
                assetWriterInput: videoInput!,
                sourcePixelBufferAttributes: sourcePixelBufferAttributes
            )
            
            if assetWriter!.canAdd(videoInput!) {
                assetWriter!.add(videoInput!)
            }
            
            // Audio Input
            let audioSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 44100.0,
                AVNumberOfChannelsKey: 1,
                AVEncoderBitRateKey: 128000
            ]
            
            audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            audioInput?.expectsMediaDataInRealTime = true
            
            if assetWriter!.canAdd(audioInput!) {
                assetWriter!.add(audioInput!)
            }
            
            // Start writing
            assetWriter?.startWriting()
            startTime = nil
            audioStartTime = nil
            lastVideoTime = .zero
            sessionStarted = false
            
            print("✅ AssetWriter ready: \(tempURL.lastPathComponent)")
            
        } catch {
            print("❌ Failed to create AssetWriter: \(error)")
        }
    }
    
    private func finishRecording() {
        guard let writer = assetWriter, writer.status == .writing else {
            print("⚠️ AssetWriter not in writing state")
            return
        }
        
        videoInput?.markAsFinished()
        audioInput?.markAsFinished()
        
        writer.finishWriting { [weak self] in
            guard let self = self else { return }
            
            switch writer.status {
            case .completed:
                print("✅ Recording completed successfully")
                if let url = self.videoURL {
                    self.saveVideoToLibrary(url: url)
                }
            case .failed:
                print("❌ Recording failed: \(writer.error?.localizedDescription ?? "unknown")")
            default:
                print("⚠️ Recording finished with status: \(writer.status.rawValue)")
            }
            
            // Reset
            self.assetWriter = nil
            self.videoInput = nil
            self.audioInput = nil
            self.pixelBufferAdaptor = nil
            self.sessionStarted = false
        }
    }
    
    // MARK: - Save to Photo Library
    
    private func saveVideoToLibrary(url: URL) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                print("❌ Photo library access denied")
                return
            }
            
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            } completionHandler: { success, error in
                DispatchQueue.main.async {
                    if success {
                        print("✅ Video saved to Photo Library")
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                    } else {
                        print("❌ Failed to save video: \(error?.localizedDescription ?? "unknown")")
                    }
                }
                // Удаляем временный файл
                try? FileManager.default.removeItem(at: url)
            }
        }
    }
    
    private func savePhotoToLibrary(pixelBuffer: CVPixelBuffer) {
        // Конвертируем CVPixelBuffer в UIImage
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            print("❌ Failed to create CGImage")
            return
        }
        
        let image = UIImage(cgImage: cgImage)
        
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                print("❌ Photo library access denied")
                return
            }
            
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            } completionHandler: { success, error in
                DispatchQueue.main.async {
                    if success {
                        print("✅ Photo saved to Photo Library")
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                    } else {
                        print("❌ Failed to save photo: \(error?.localizedDescription ?? "unknown")")
                    }
                }
            }
        }
    }
    
    // MARK: - Recording Timer
    
    private func startRecordingTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.recordingDuration += 0.1
        }
    }
    
    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }
}
