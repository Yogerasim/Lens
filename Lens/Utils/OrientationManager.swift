import Combine
import SwiftUI
import UIKit

@MainActor
final class OrientationManager: ObservableObject {
  static let shared = OrientationManager()

  @Published var currentOrientation: UIInterfaceOrientation = .portrait
  @Published var rotationAngle: Float = 0.0  // в радианах для Metal

  private var cancellables = Set<AnyCancellable>()

  init() {

    NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)
      .sink { [weak self] _ in
        self?.updateOrientation()
      }
      .store(in: &cancellables)

    updateOrientation()
  }

  private func updateOrientation() {

    guard
      let windowScene = UIApplication.shared.connectedScenes
        .compactMap({ $0 as? UIWindowScene })
        .first
    else {
      DebugLog.warning("OrientationManager: No window scene found")
      return
    }

    let newOrientation = windowScene.interfaceOrientation
    let newRotationAngle = rotationAngleFor(orientation: newOrientation)

    if newOrientation != currentOrientation {
      currentOrientation = newOrientation
      rotationAngle = newRotationAngle
    }
  }

  private func rotationAngleFor(orientation: UIInterfaceOrientation) -> Float {

    switch orientation {
    case .portrait:
      return Float.pi / 2.0  // 90° - поворачиваем landscape буфер в portrait
    case .landscapeRight:
      return 0.0  // 0° - буфер уже в правильной ориентации
    case .landscapeLeft:
      return Float.pi  // 180° - поворачиваем на 180°
    case .portraitUpsideDown:
      return -Float.pi / 2.0  // -90°
    default:
      return Float.pi / 2.0  // default к portrait
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

  func forceUpdate() {
    updateOrientation()
  }
}
