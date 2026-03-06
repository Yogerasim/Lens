import CoreImage
import CoreVideo

enum PixelBufferScaler {

  static let ciContext = CIContext(options: [
    .cacheIntermediates: false
  ])

  static func resize(
    _ pixelBuffer: CVPixelBuffer,
    to size: CGSize
  ) -> CVPixelBuffer? {

    let ciImage = CIImage(cvPixelBuffer: pixelBuffer)

    let scaleX = size.width / ciImage.extent.width
    let scaleY = size.height / ciImage.extent.height

    let resized = ciImage.transformed(
      by: CGAffineTransform(scaleX: scaleX, y: scaleY)
    )

    var output: CVPixelBuffer?

    let attrs: [CFString: Any] = [
      kCVPixelBufferMetalCompatibilityKey: true,
      kCVPixelBufferWidthKey: Int(size.width),
      kCVPixelBufferHeightKey: Int(size.height),
      kCVPixelBufferPixelFormatTypeKey:
        kCVPixelFormatType_32BGRA,
    ]

    CVPixelBufferCreate(
      kCFAllocatorDefault,
      Int(size.width),
      Int(size.height),
      kCVPixelFormatType_32BGRA,
      attrs as CFDictionary,
      &output
    )

    guard let outputBuffer = output else { return nil }

    ciContext.render(resized, to: outputBuffer)
    return outputBuffer
  }
}
