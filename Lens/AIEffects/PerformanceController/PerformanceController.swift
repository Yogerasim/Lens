import Foundation
import UIKit

protocol PerformanceControlling {
  var policy: PerformancePolicy { get }
  func update(frameTime: CFTimeInterval)
}

enum PerformancePolicy {
  case ultra  // latest iPhones, cold device
  case balanced  // default
  case safe  // thermal pressure
  case survival  // overheating
}

final class PerformanceController: PerformanceControlling {

  static let shared = PerformanceController()

  private(set) var policy: PerformancePolicy = .balanced

  private var frameTimes: [CFTimeInterval] = []
  private let maxSamples = 30

  private init() {
    observeThermals()
  }

  func update(frameTime: CFTimeInterval) {
    frameTimes.append(frameTime)

    if frameTimes.count > maxSamples {
      frameTimes.removeFirst()
    }

    let avg = frameTimes.reduce(0, +) / Double(frameTimes.count)
    evaluate(avgFrameTime: avg)
  }

  private func evaluate(avgFrameTime: CFTimeInterval) {
    let thermal = ProcessInfo.processInfo.thermalState

    switch (thermal, avgFrameTime) {

    case (.nominal, ..<0.03):
      policy = .ultra

    case (.fair, ..<0.035):
      policy = .balanced

    case (.serious, _):
      policy = .safe

    case (.critical, _):
      policy = .survival

    default:
      policy = .balanced
    }
  }

  private func observeThermals() {
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(onThermalChange),
      name: ProcessInfo.thermalStateDidChangeNotification,
      object: nil
    )
  }

  @objc private func onThermalChange() {
    frameTimes.removeAll()
  }
}
