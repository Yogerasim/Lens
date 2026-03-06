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
    
    // Кэшируем последний drawableSize для сравнения
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
        
        // Обновляем frame
        metalLayer.frame = bounds
        
        // ✅ FIX: Используем nativeScale из window (не UIScreen.main.scale)
        // Это критично для iPad в Split View, Stage Manager или внешний дисплей
        let nativeScale = window?.screen.nativeScale ?? UIScreen.main.nativeScale
        
        // Устанавливаем contentsScale из nativeScale
        metalLayer.contentsScale = nativeScale
        
        // ✅ FIX: Вычисляем drawableSize в пикселях (points * scale)
        let drawableSize = CGSize(
            width: bounds.width * nativeScale,
            height: bounds.height * nativeScale
        )
        
        // Обновляем только при изменении (избегаем лишних обновлений)
        if lastDrawableSize != drawableSize {
            lastDrawableSize = drawableSize
            metalLayer.drawableSize = drawableSize
        }
    }
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        
        // ✅ FIX: Обновляем scale когда view добавлен в window
        // Важно для корректного nativeScale на iPad
        if window != nil {
            setNeedsLayout()
            layoutIfNeeded()
        }
    }
}
