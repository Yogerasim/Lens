import SwiftUI
import UIKit
import Combine

@MainActor
final class OrientationManager: ObservableObject {
    static let shared = OrientationManager()
    
    @Published var currentOrientation: UIInterfaceOrientation = .portrait
    @Published var rotationAngle: Float = 0.0 // в радианах для Metal
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Подписываемся на изменения ориентации
        NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)
            .sink { [weak self] _ in
                self?.updateOrientation()
            }
            .store(in: &cancellables)
        
        // Инициализируем текущую ориентацию
        updateOrientation()
    }
    
    private func updateOrientation() {
        // Получаем ориентацию из window scene (iOS 17+)
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first else {
            DebugLog.warning("OrientationManager: No window scene found")
            return
        }
        
        let newOrientation = windowScene.interfaceOrientation
        let newRotationAngle = rotationAngleFor(orientation: newOrientation)
        
        if newOrientation != currentOrientation {
            currentOrientation = newOrientation
            rotationAngle = newRotationAngle
            
            let degrees = Int(newRotationAngle * 180 / .pi)
        }
    }
    
    private func rotationAngleFor(orientation: UIInterfaceOrientation) -> Float {
        // Вычисляем rotation для Metal uniforms
        // Предполагаем что AVCaptureVideoDataOutput даёт буфер в landscape формате
        switch orientation {
        case .portrait:
            return Float.pi / 2.0    // 90° - поворачиваем landscape буфер в portrait
        case .landscapeRight:
            return 0.0               // 0° - буфер уже в правильной ориентации
        case .landscapeLeft:
            return Float.pi          // 180° - поворачиваем на 180°
        case .portraitUpsideDown:
            return -Float.pi / 2.0   // -90°
        default:
            return Float.pi / 2.0    // default к portrait
        }
    }
    
    private func orientationName(_ orientation: UIInterfaceOrientation) -> String {
        switch orientation {
        case .portrait: return "portrait"
        case .landscapeLeft: return "landscapeLeft"
        case .landscapeRight: return "landscapeRight"
        case .portraitUpsideDown: return "portraitUpsideDown"
        default: return "unknown"
        }
    }
    
    // Публичный метод для принудительного обновления
    func forceUpdate() {
        updateOrientation()
    }
}