import SwiftUI
import MetalKit

struct MetalView: UIViewRepresentable {

    let renderer: MetalRenderer

    func makeUIView(context: Context) -> UIView {
        let view = MetalHostView(metalLayer: renderer.metalLayer)
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // layoutSubviews в MetalHostView обновит drawableSize автоматически
    }
}

// MARK: - Custom UIView для корректного обновления drawableSize
final class MetalHostView: UIView {
    
    private let metalLayer: CAMetalLayer
    
    init(metalLayer: CAMetalLayer) {
        self.metalLayer = metalLayer
        super.init(frame: .zero)
        
        metalLayer.contentsScale = UIScreen.main.scale
        layer.addSublayer(metalLayer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Обновляем frame и drawableSize при любом изменении layout
        metalLayer.frame = bounds
        
        let scale = UIScreen.main.scale
        let drawableSize = CGSize(
            width: bounds.width * scale,
            height: bounds.height * scale
        )
        
        if metalLayer.drawableSize != drawableSize {
            metalLayer.drawableSize = drawableSize
            print("🧱 MetalLayer drawableSize updated:", drawableSize)
        }
    }
}
