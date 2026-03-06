internal import AVFoundation
import CoreVideo

final class CameraSessionController: NSObject {
    let session = AVCaptureSession()

    let sessionQueue = DispatchQueue(label: "camera.session.queue")
    let outputQueue = DispatchQueue(label: "camera.output.queue")
    let audioOutputQueue = DispatchQueue(label: "camera.audio.queue")

    nonisolated(unsafe) let videoOutput = AVCaptureVideoDataOutput()
    nonisolated(unsafe) let audioOutput = AVCaptureAudioDataOutput()

    private(set) var currentInput: AVCaptureDeviceInput?
    private(set) var audioInput: AVCaptureDeviceInput?

    var onFrame: ((CVPixelBuffer, CMTime) -> Void)?
    var onAudioSample: ((CMSampleBuffer) -> Void)?

    override init() {
        super.init()
    }

    func configureOutputs() {
        configureAudioInputIfNeeded()

        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput.setSampleBufferDelegate(self, queue: outputQueue)
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }

        audioOutput.setSampleBufferDelegate(self, queue: audioOutputQueue)
        if session.canAddOutput(audioOutput) {
            session.addOutput(audioOutput)
        }
    }

    func configureAudioInputIfNeeded() {
        sessionQueue.async {
            if self.audioInput != nil { return }

            if AVCaptureDevice.authorizationStatus(for: .audio) == .authorized {
                guard let mic = AVCaptureDevice.default(for: .audio) else {
                    DebugLog.warning("No audio device available")
                    return
                }

                do {
                    let input = try AVCaptureDeviceInput(device: mic)
                    if self.session.canAddInput(input) {
                        self.session.addInput(input)
                        self.audioInput = input
                    }
                } catch {
                    DebugLog.warning("Failed to create audio input: \(error)")
                }
            } else {
                DebugLog.warning("Audio permission not granted")
            }
        }
    }

    func startSession(updateZoomLimits: @escaping (AVCaptureDevice) -> Void) {
        sessionQueue.async {
            if !self.session.isRunning {
                self.session.startRunning()
                if let device = self.currentInput?.device {
                    updateZoomLimits(device)
                }
            }
        }
    }

    func stopSession() {
        sessionQueue.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    func replaceCurrentInput(with input: AVCaptureDeviceInput) {
        currentInput = input
    }

    func removeCurrentInputIfNeeded() {
        if let existing = currentInput {
            session.removeInput(existing)
            currentInput = nil
        }
    }

    func beginConfiguration() {
        session.beginConfiguration()
    }

    func commitConfiguration() {
        session.commitConfiguration()
    }
}

extension CameraSessionController: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        if output == videoOutput {
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            onFrame?(pixelBuffer, time)
        } else if output == audioOutput {
            onAudioSample?(sampleBuffer)
        }
    }
}
