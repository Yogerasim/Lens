internal import AVFoundation

final class CameraDeviceConfigurator {
    func configureCamera(
        session: AVCaptureSession,
        currentInput: AVCaptureDeviceInput?,
        device: AVCaptureDevice,
        enableDepth: Bool,
        currentPosition: AVCaptureDevice.Position,
        videoOutput: AVCaptureVideoDataOutput,
        formatSelector: CameraFormatSelector
    ) throws -> AVCaptureDeviceInput {
        if let existing = currentInput {
            session.removeInput(existing)
        }

        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else {
            throw ConfigurationError.cannotAddInput
        }
        session.addInput(input)

        let selectedFormat: AVCaptureDevice.Format?
        if enableDepth {
            selectedFormat = formatSelector.findBestDepthFormat(for: device)
            if selectedFormat == nil {
                throw ConfigurationError.noDepthCompatibleFormat
            }
        } else {
            selectedFormat = formatSelector.findBestFormat(for: device)
        }

        if let format = selectedFormat {
            try configureFormat(
                device: device,
                format: format,
                targetFPS: formatSelector.chooseFrameRate(for: format)
            )
        }

        configureVideoConnection(
            videoOutput: videoOutput,
            currentPosition: currentPosition,
            enableDepth: enableDepth
        )

        DepthManager.shared.removeDepthOutput(from: session)
        if enableDepth {
            DepthManager.shared.setupDepthOutput(for: session)
            synchronizeDepthOrientation(
                videoOutput: videoOutput,
                depthOutput: DepthManager.shared.depthOutput,
                currentPosition: currentPosition
            )
        }

        return input
    }

    private func configureFormat(
        device: AVCaptureDevice,
        format: AVCaptureDevice.Format,
        targetFPS: Double
    ) throws {
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }

        if device.activeFormat != format {
            device.activeFormat = format
        }

        let frameDuration = CMTime(value: 1, timescale: CMTimeScale(targetFPS))
        device.activeVideoMinFrameDuration = frameDuration
        device.activeVideoMaxFrameDuration = frameDuration
    }

    private func configureVideoConnection(
        videoOutput: AVCaptureVideoDataOutput,
        currentPosition: AVCaptureDevice.Position,
        enableDepth: Bool
    ) {
        guard let connection = videoOutput.connection(with: .video) else {
            return
        }

        let shouldMirror = false

        if #available(iOS 17.0, *) {
            connection.videoRotationAngle = 90
        } else if connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }

        if connection.isVideoMirroringSupported {
            connection.isVideoMirrored = shouldMirror
        }

        if connection.isVideoStabilizationSupported {
            connection.preferredVideoStabilizationMode = enableDepth ? .off : .standard
        } else {
            connection.preferredVideoStabilizationMode = .off
        }
    }

    private func synchronizeDepthOrientation(
        videoOutput: AVCaptureVideoDataOutput,
        depthOutput: AVCaptureDepthDataOutput?,
        currentPosition: AVCaptureDevice.Position
    ) {
        guard let videoConnection = videoOutput.connection(with: .video),
              let depthOutput,
              let depthConnection = depthOutput.connection(with: .depthData) else {
            return
        }

        let shouldMirror = false

        if #available(iOS 17.0, *) {
            if videoConnection.isVideoRotationAngleSupported(90) {
                videoConnection.videoRotationAngle = 90
            }
        } else if videoConnection.isVideoOrientationSupported {
            videoConnection.videoOrientation = .portrait
        }

        if videoConnection.isVideoMirroringSupported {
            videoConnection.isVideoMirrored = shouldMirror
        }

        if videoConnection.isVideoStabilizationSupported {
            videoConnection.preferredVideoStabilizationMode = .off
        }

        if #available(iOS 17.0, *) {
            if depthConnection.isVideoRotationAngleSupported(90) {
                depthConnection.videoRotationAngle = 90
            }
        } else if depthConnection.isVideoOrientationSupported {
            depthConnection.videoOrientation = .portrait
        }

        if depthConnection.isVideoMirroringSupported {
            depthConnection.isVideoMirrored = shouldMirror
        }
    }
}

extension CameraDeviceConfigurator {
    enum ConfigurationError: LocalizedError {
        case cannotAddInput
        case noDepthCompatibleFormat
        var errorDescription: String? {
            switch self {
            case .cannotAddInput:
                return "Cannot add device input"
            case .noDepthCompatibleFormat:
                return "No depth-compatible format found"
            }
        }
    }
}
