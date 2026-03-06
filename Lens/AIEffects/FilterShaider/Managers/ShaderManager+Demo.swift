import Combine
import Foundation
import ObjectiveC

extension ShaderManager {

  struct DemoConfig: Equatable {
    var isOn: Bool
    var interval: TimeInterval
    var maxCount: Int
    var onlyNonDepth: Bool
    var disableWhileRecording: Bool

    static let `default` = DemoConfig(
      isOn: false,
      interval: 2.0,
      maxCount: 12,
      onlyNonDepth: false,
      disableWhileRecording: true
    )
  }

  private enum Assoc {
    static var demoCancellableKey: UInt8 = 0
    static var demoConfigKey: UInt8 = 0
  }

  private var demoCancellable: AnyCancellable? {
    get { objc_getAssociatedObject(self, &Assoc.demoCancellableKey) as? AnyCancellable }
    set {
      objc_setAssociatedObject(
        self, &Assoc.demoCancellableKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
  }

  private var demoConfig: DemoConfig {
    get { (objc_getAssociatedObject(self, &Assoc.demoConfigKey) as? DemoConfig) ?? .default }
    set {
      objc_setAssociatedObject(
        self, &Assoc.demoConfigKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
  }

  func setDemo(config: DemoConfig) {
    demoConfig = config
    config.isOn ? startDemo() : stopDemo()
  }

  func stopDemo() {
    demoCancellable?.cancel()
    demoCancellable = nil

    var cfg = demoConfig
    cfg.isOn = false
    demoConfig = cfg
  }

  private func startDemo() {
    stopDemo()

    let cfg = demoConfig
    let interval = max(0.2, cfg.interval)

    demoCancellable =
      Timer
      .publish(every: interval, on: .main, in: .common)
      .autoconnect()
      .sink { [weak self] _ in
        self?.demoStep()
      }
  }

  private func demoStep() {
    let cfg = demoConfig

    if cfg.disableWhileRecording, FramePipeline.shared.isRecording {
      return
    }

    let isFront = FramePipeline.shared.cameraManager?.isFrontCamera ?? false
    let isRecording = FramePipeline.shared.isRecording
    let recordingFamily = FramePipeline.shared.recordingFilterFamily

    var available = FilterLibrary.shared.availableFilters(
      isFront: isFront,
      recordingFamily: recordingFamily,
      isRecording: isRecording
    )

    if cfg.onlyNonDepth {
      available = available.filter { $0.needsDepth == false }
    }

    guard !available.isEmpty else { return }

    let limited = Array(available.prefix(max(1, cfg.maxCount)))
    let idx = limited.firstIndex(where: { $0.shaderName == currentFragment }) ?? -1
    let next = (idx + 1) % limited.count

    select(fragment: limited[next].shaderName)
  }
}
