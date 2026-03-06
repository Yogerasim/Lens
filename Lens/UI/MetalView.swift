import MetalKit
import SwiftUI

struct MetalView: UIViewRepresentable {

  let renderer: MetalRenderer

  func makeUIView(context: Context) -> UIView {
    let view = MetalHostView(metalLayer: renderer.metalLayer)
    view.backgroundColor = .black
    return view
  }

  func updateUIView(_ uiView: UIView, context: Context) {

  }
}

final class MetalHostView: UIView {

  private let metalLayer: CAMetalLayer

  private var lastDrawableSize: CGSize = .zero

  init(metalLayer: CAMetalLayer) {
    self.metalLayer = metalLayer
    super.init(frame: .zero)

    layer.addSublayer(metalLayer)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func layoutSubviews() {
    super.layoutSubviews()

    metalLayer.frame = bounds

    let nativeScale = window?.screen.nativeScale ?? UIScreen.main.nativeScale

    metalLayer.contentsScale = nativeScale

    let drawableSize = CGSize(
      width: bounds.width * nativeScale,
      height: bounds.height * nativeScale
    )

    if lastDrawableSize != drawableSize {
      lastDrawableSize = drawableSize
      metalLayer.drawableSize = drawableSize
    }
  }

  override func didMoveToWindow() {
    super.didMoveToWindow()

    if window != nil {
      setNeedsLayout()
      layoutIfNeeded()
    }
  }
}
