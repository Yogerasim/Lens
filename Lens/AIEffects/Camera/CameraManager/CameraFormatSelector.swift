internal import AVFoundation

struct CameraFormatSelector {
  func findBestDepthFormat(for device: AVCaptureDevice) -> AVCaptureDevice.Format? {
    let depthFormats = device.formats.filter { !$0.supportedDepthDataFormats.isEmpty }
    guard !depthFormats.isEmpty else { return nil }

    let preferredWidths: [Int32] = [1920, 1280]

    for preferredWidth in preferredWidths {
      let candidates = depthFormats.filter {
        CMVideoFormatDescriptionGetDimensions($0.formatDescription).width == preferredWidth
      }
      if let best = candidates.max(by: { effectiveMaxFPS(for: $0) < effectiveMaxFPS(for: $1) }) {
        return best
      }
    }

    let fallback = depthFormats.max { lhs, rhs in
      let lhsFPS = effectiveMaxFPS(for: lhs)
      let rhsFPS = effectiveMaxFPS(for: rhs)
      if lhsFPS != rhsFPS { return lhsFPS < rhsFPS }

      let lhsDim = CMVideoFormatDescriptionGetDimensions(lhs.formatDescription)
      let rhsDim = CMVideoFormatDescriptionGetDimensions(rhs.formatDescription)
      return lhsDim.width * lhsDim.height < rhsDim.width * rhsDim.height
    }

    return fallback
  }

  func findBestFormat(for device: AVCaptureDevice) -> AVCaptureDevice.Format? {
    let preferredFPS = Double(DeviceCapabilities.current.maxFPS)
    let preferredWidths: [Int32] = [1920, 1280]
    let formats = device.formats

    for preferredWidth in preferredWidths {
      let candidates = formats.filter {
        CMVideoFormatDescriptionGetDimensions($0.formatDescription).width == preferredWidth
          && effectiveMaxFPS(for: $0) >= min(30.0, preferredFPS)
      }

      if let best = candidates.max(by: {
        scoreForVideoFormat($0, preferredFPS: preferredFPS)
          < scoreForVideoFormat($1, preferredFPS: preferredFPS)
      }) {
        return best
      }
    }

    let fallback = formats.max {
      scoreForVideoFormat($0, preferredFPS: preferredFPS)
        < scoreForVideoFormat($1, preferredFPS: preferredFPS)
    }

    return fallback ?? device.activeFormat
  }

  func chooseFrameRate(for format: AVCaptureDevice.Format) -> Double {
    let formatMax = format.videoSupportedFrameRateRanges.map(\.maxFrameRate).max() ?? 30
    let desired = min(formatMax, Double(DeviceCapabilities.current.maxFPS))

    if desired >= 59.0 { return 60.0 }
    if desired >= 29.0 { return 30.0 }
    return max(1.0, floor(desired))
  }

  private func scoreForVideoFormat(_ format: AVCaptureDevice.Format, preferredFPS: Double) -> Double
  {
    let maxFPS = effectiveMaxFPS(for: format)
    let dim = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
    let pixels = Double(dim.width * dim.height)

    let fpsScore: Double
    if maxFPS >= preferredFPS {
      fpsScore = 10_000
    } else if maxFPS >= 30 {
      fpsScore = 5_000
    } else {
      fpsScore = maxFPS * 100
    }

    let preferredResolutionBonus: Double
    switch dim.width {
    case 1920: preferredResolutionBonus = 2_000
    case 1280: preferredResolutionBonus = 1_000
    default: preferredResolutionBonus = 0
    }

    return fpsScore + preferredResolutionBonus + pixels / 1_000_000
  }

  private func effectiveMaxFPS(for format: AVCaptureDevice.Format) -> Double {
    let formatMax = format.videoSupportedFrameRateRanges.map(\.maxFrameRate).max() ?? 30
    return min(formatMax, Double(DeviceCapabilities.current.maxFPS))
  }
}
