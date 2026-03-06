import Foundation

enum DebugLog {
    static var isEnabled = false
    static var cameraEnabled = false
    static var renderEnabled = false
    static var zoomEnabled = false
    static var depthEnabled = false
    static var voiceEnabled = false

    static func info(_ message: @autoclosure () -> String) {
        guard isEnabled else { return }
        print("ℹ️ \(message())")
    }

    static func camera(_ message: @autoclosure () -> String) {
        guard isEnabled && cameraEnabled else { return }
        print("📷 \(message())")
    }

    static func render(_ message: @autoclosure () -> String) {
        guard isEnabled && renderEnabled else { return }
        print("🖼️ \(message())")
    }

    static func zoom(_ message: @autoclosure () -> String) {
        guard isEnabled && zoomEnabled else { return }
        print("🔍 \(message())")
    }

    static func depth(_ message: @autoclosure () -> String) {
        guard isEnabled && depthEnabled else { return }
        print("📊 \(message())")
    }

    static func voice(_ message: @autoclosure () -> String) {
        guard isEnabled && voiceEnabled else { return }
        print("🎤 \(message())")
    }

    static func warning(_ message: @autoclosure () -> String) {
        print("⚠️ \(message())")
    }

    static func error(_ message: @autoclosure () -> String) {
        print("❌ \(message())")
    }
}
