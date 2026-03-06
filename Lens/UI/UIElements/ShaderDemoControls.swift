import SwiftUI

struct ShaderDemoControls: View {
  @ObservedObject private var shaders = ShaderManager.shared

  @AppStorage("demo_isOn") private var isOn = false
  @AppStorage("demo_interval") private var interval = 2.0
  @AppStorage("demo_maxCount") private var maxCount = 12
  @AppStorage("demo_onlyNonDepth") private var onlyNonDepth = false
  @AppStorage("demo_disableWhileRecording") private var disableWhileRecording = true

  var body: some View {
    VStack(spacing: 14) {
      HStack {
        Text("Demo mode")
          .font(.headline)
        Spacer()
        Toggle("", isOn: $isOn)
          .labelsHidden()
      }

      VStack(spacing: 10) {
        HStack {
          Text("Seconds")
          Spacer()
          Text("\(interval, specifier: "%.1f")")
            .monospacedDigit()
            .foregroundStyle(.secondary)
        }
        Slider(value: $interval, in: 0.5...6.0, step: 0.5)

        HStack {
          Text("Count")
          Spacer()
          Text("\(maxCount)")
            .monospacedDigit()
            .foregroundStyle(.secondary)
        }
        Slider(
          value: Binding(
            get: { Double(maxCount) },
            set: { maxCount = Int($0) }
          ),
          in: 3...24,
          step: 1
        )
      }

      Toggle("Only non-depth filters", isOn: $onlyNonDepth)
      Toggle("Pause while recording", isOn: $disableWhileRecording)

      Spacer(minLength: 0)
    }
    .padding(16)
    .presentationDragIndicator(.visible)
    .onAppear { apply() }
    .onChange(of: isOn) { _, _ in apply() }
    .onChange(of: interval) { _, _ in apply() }
    .onChange(of: maxCount) { _, _ in apply() }
    .onChange(of: onlyNonDepth) { _, _ in apply() }
    .onChange(of: disableWhileRecording) { _, _ in apply() }
  }

  private func apply() {
    shaders.setDemo(
      config: .init(
        isOn: isOn,
        interval: interval,
        maxCount: maxCount,
        onlyNonDepth: onlyNonDepth,
        disableWhileRecording: disableWhileRecording
      ))
  }
}
