import UIKit
import Combine

final class OrientationManager: ObservableObject {
    static let shared = OrientationManager()

    @Published private(set) var currentOrientation: UIDeviceOrientation = .portrait
    @Published private(set) var rotationAngle: Float = 0.0

    private init() {
        if Thread.isMainThread {
            updateOrientation()
            startObserving()
        } else {
            DispatchQueue.main.sync {
                self.updateOrientation()
                self.startObserving()
            }
        }
    }

    private func startObserving() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOrientationChange),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
    }

    @objc private func handleOrientationChange() {
        updateOrientation()
    }

    private func updateOrientation() {
        if Thread.isMainThread {
            applyCurrentInterfaceOrientation()
        } else {
            DispatchQueue.main.async {
                self.applyCurrentInterfaceOrientation()
            }
        }
    }

    private func applyCurrentInterfaceOrientation() {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first else {
            return
        }

        let interfaceOrientation = windowScene.interfaceOrientation

        let newOrientation: UIDeviceOrientation
        let newRotation: Float

        switch interfaceOrientation {
        case .portrait:
            newOrientation = .portrait
            newRotation = 0.0
        case .portraitUpsideDown:
            newOrientation = .portraitUpsideDown
            newRotation = .pi
        case .landscapeLeft:
            newOrientation = .landscapeRight
            newRotation = -.pi / 2.0
        case .landscapeRight:
            newOrientation = .landscapeLeft
            newRotation = .pi / 2.0
        default:
            newOrientation = .portrait
            newRotation = 0.0
        }

        if currentOrientation != newOrientation {
            currentOrientation = newOrientation
        }

        if rotationAngle != newRotation {
            rotationAngle = newRotation
        }
    }
}
