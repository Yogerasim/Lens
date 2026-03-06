internal import AVFoundation
import Combine
import Photos
import UIKit

enum CaptureMode: String, CaseIterable {
  case photo = "ФОТО"
  case video = "ВИДЕО"
}

final class MediaRecorder: NSObject, ObservableObject {

  @Published var isRecording = false
  @Published var recordingDuration: TimeInterval = 0
  @Published var captureMode: CaptureMode = .video

  private var assetWriter: AVAssetWriter?
  private var videoInput: AVAssetWriterInput?
  private var audioInput: AVAssetWriterInput?
  private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?

  private var videoURL: URL?

  private var sessionBaseTime: CMTime?
  private var lastVideoTime: CMTime = .zero
  private var recordingTimer: Timer?
  private var sessionStarted = false

  private var videoFrameCount: Int64 = 0

  private var audioSampleCount: Int64 = 0

  private let writerQueue = DispatchQueue(label: "media.recorder.queue", qos: .userInitiated)

  private var videoWidth: Int {
    DeviceCapabilities.currentCameraWidth
  }
  private var videoHeight: Int {
    DeviceCapabilities.currentCameraHeight
  }

  private var lastRenderedBuffer: CVPixelBuffer?

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

  func appendVideoFrame(_ pixelBuffer: CVPixelBuffer, sampleTime: CMTime, hasDepth: Bool = false) {

    lastRenderedBuffer = pixelBuffer

    guard isRecording else { return }

    writerQueue.async {
      guard let writer = self.assetWriter,
        writer.status == .writing,
        let adaptor = self.pixelBufferAdaptor,
        let input = self.videoInput,
        input.isReadyForMoreMediaData
      else { return }

      if !self.sessionStarted {
        self.sessionBaseTime = sampleTime
        self.videoFrameCount = 0
        self.audioSampleCount = 0
        writer.startSession(atSourceTime: sampleTime)
        self.sessionStarted = true
      }

      guard let baseTime = self.sessionBaseTime else { return }
      if CMTimeCompare(sampleTime, baseTime) < 0 { return }

      if CMTimeCompare(sampleTime, self.lastVideoTime) <= 0 && self.videoFrameCount > 0 {
        return
      }

      self.videoFrameCount += 1

      if adaptor.append(pixelBuffer, withPresentationTime: sampleTime) {
        self.lastVideoTime = sampleTime

        DispatchQueue.main.async {
          FPSCounter.shared.tickRecording()
        }
      } else {
        DebugLog.error(
          "Failed to append video frame \(self.videoFrameCount), writer.status=\(writer.status.rawValue)"
        )
      }
    }
  }

  func appendAudioSample(_ sampleBuffer: CMSampleBuffer) {
    guard isRecording else { return }

    writerQueue.async {
      guard let writer = self.assetWriter,
        writer.status == .writing,
        self.sessionStarted,
        let input = self.audioInput,
        input.isReadyForMoreMediaData
      else { return }

      guard let baseTime = self.sessionBaseTime else { return }
      let audioTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
      if CMTimeCompare(audioTime, baseTime) < 0 { return }

      self.audioSampleCount += 1

      if !input.append(sampleBuffer) {
        DebugLog.error("Failed to append audio sample \(self.audioSampleCount)")
      }
    }
  }

  func takePhoto() {
    guard let buffer = lastRenderedBuffer else {
      DebugLog.error("No rendered frame available for photo")
      return
    }

    writerQueue.async {
      self.savePhotoToLibrary(pixelBuffer: buffer)
    }
  }

  private func setupAssetWriter() {
    let fileName = "Lens_\(Date().timeIntervalSince1970).mp4"
    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

    try? FileManager.default.removeItem(at: tempURL)

    do {
      assetWriter = try AVAssetWriter(url: tempURL, fileType: .mp4)
      videoURL = tempURL

      let videoSettings: [String: Any] = [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: videoWidth,
        AVVideoHeightKey: videoHeight,
        AVVideoCompressionPropertiesKey: [
          AVVideoAverageBitRateKey: 10_000_000,
          AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
        ],
      ]

      videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
      videoInput?.expectsMediaDataInRealTime = true

      let sourcePixelBufferAttributes: [String: Any] = [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferWidthKey as String: videoWidth,
        kCVPixelBufferHeightKey as String: videoHeight,
      ]

      pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
        assetWriterInput: videoInput!,
        sourcePixelBufferAttributes: sourcePixelBufferAttributes
      )

      if assetWriter!.canAdd(videoInput!) {
        assetWriter!.add(videoInput!)
      }

      let audioSettings: [String: Any] = [
        AVFormatIDKey: kAudioFormatMPEG4AAC,
        AVSampleRateKey: 44100.0,
        AVNumberOfChannelsKey: 1,
        AVEncoderBitRateKey: 128000,
      ]

      audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
      audioInput?.expectsMediaDataInRealTime = true

      if assetWriter!.canAdd(audioInput!) {
        assetWriter!.add(audioInput!)
      }

      assetWriter?.startWriting()
      sessionBaseTime = nil
      lastVideoTime = .zero
      sessionStarted = false
      videoFrameCount = 0
      audioSampleCount = 0

    } catch {
      DebugLog.error("Failed to create AssetWriter: \(error)")
    }
  }

  private func finishRecording() {
    guard let writer = assetWriter, writer.status == .writing else {
      DebugLog.warning("AssetWriter not in writing state")
      return
    }

    videoInput?.markAsFinished()
    audioInput?.markAsFinished()

    let totalFrames = videoFrameCount
    let totalAudioSamples = audioSampleCount
    let elapsed: Double
    if let base = sessionBaseTime {
      elapsed = CMTimeSubtract(lastVideoTime, base).seconds
    } else {
      elapsed = 0
    }

    writer.finishWriting { [weak self] in
      guard let self = self else { return }

      switch writer.status {
      case .completed:
        let avgFPS = elapsed > 0 ? Double(totalFrames) / elapsed : 0
        print(
          "✅ Recording completed: \(totalFrames) frames, \(totalAudioSamples) audio samples, \(String(format: "%.1f", elapsed))s, avg \(String(format: "%.1f", avgFPS)) fps"
        )
        if let url = self.videoURL {
          self.saveVideoToLibrary(url: url)
        }
      case .failed:
        DebugLog.error("Recording failed: \(writer.error?.localizedDescription ?? "unknown")")
      default:
        DebugLog.warning("Recording finished with status: \(writer.status.rawValue)")
      }

      self.assetWriter = nil
      self.videoInput = nil
      self.audioInput = nil
      self.pixelBufferAdaptor = nil
      self.sessionStarted = false

      DispatchQueue.main.async {
        FPSCounter.shared.recordingFPS = 0
      }
    }
  }

  private func saveVideoToLibrary(url: URL) {
    PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
      guard status == .authorized || status == .limited else {
        DebugLog.error("Photo library access denied")
        return
      }

      PHPhotoLibrary.shared().performChanges {
        PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
      } completionHandler: { success, error in
        DispatchQueue.main.async {
          if success {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
          } else {
            DebugLog.error("Failed to save video: \(error?.localizedDescription ?? "unknown")")
          }
        }

        try? FileManager.default.removeItem(at: url)
      }
    }
  }

  private func savePhotoToLibrary(pixelBuffer: CVPixelBuffer) {

    let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
    let context = CIContext()

    guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
      DebugLog.error("Failed to create CGImage")
      return
    }

    let image = UIImage(cgImage: cgImage)

    PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
      guard status == .authorized || status == .limited else {
        DebugLog.error("Photo library access denied")
        return
      }

      PHPhotoLibrary.shared().performChanges {
        PHAssetChangeRequest.creationRequestForAsset(from: image)
      } completionHandler: { success, error in
        DispatchQueue.main.async {
          if success {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
          } else {
            DebugLog.error("Failed to save photo: \(error?.localizedDescription ?? "unknown")")
          }
        }
      }
    }
  }

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
