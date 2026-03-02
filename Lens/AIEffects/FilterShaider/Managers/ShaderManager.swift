import Metal
import Foundation
import Combine
import QuartzCore

final class ShaderManager: ObservableObject {
    static let shared = ShaderManager()

    @Published private(set) var currentFragment: String = "fragment_comic"
    @Published private(set) var currentIndex: Int = 0   // индекс В СПИСКЕ доступных фильтров

    private let device: MTLDevice = MetalContext.shared.device
    private var pipelines: [String: MTLRenderPipelineState] = [:]
    private var startTime: CFTimeInterval = CACurrentMediaTime()

    private lazy var library: MTLLibrary = {
        guard let lib = device.makeDefaultLibrary() else {
            fatalError("❌ Failed to load Metal library")
        }
        return lib
    }()

    var currentPipeline: MTLRenderPipelineState { pipeline(for: currentFragment) }
    var animationTime: Float { Float(CACurrentMediaTime() - startTime) }

    // ✅ Для UI (CameraTopBar)
    var currentDisplayName: String {
        FilterLibrary.shared.filter(for: currentFragment)?.name
        ?? currentFragment.replacingOccurrences(of: "fragment_", with: "")
    }

    func select(fragment: String) {
        currentFragment = fragment
        FramePipeline.shared.setActiveFilter(by: fragment)
        syncIndexWithAvailableFilters()
    }

    // ✅ Swipe support (CameraCanvasView)
    func nextShader() { step(+1) }
    func previousShader() { step(-1) }

    private func step(_ delta: Int) {
        let isFront = FramePipeline.shared.cameraManager?.isFrontCamera ?? false
        let isRecording = FramePipeline.shared.isRecording
        let recordingFamily = FramePipeline.shared.recordingFilterFamily

        let available = FilterLibrary.shared.availableFilters(
            isFront: isFront,
            recordingFamily: recordingFamily,
            isRecording: isRecording
        )

        guard !available.isEmpty else { return }

        let currentIdx = available.firstIndex(where: { $0.shaderName == currentFragment }) ?? 0
        let next = (currentIdx + delta + available.count) % available.count

        let fragment = available[next].shaderName
        currentIndex = next
        currentFragment = fragment
        FramePipeline.shared.setActiveFilter(by: fragment)
    }

    private func syncIndexWithAvailableFilters() {
        let isFront = FramePipeline.shared.cameraManager?.isFrontCamera ?? false
        let isRecording = FramePipeline.shared.isRecording
        let recordingFamily = FramePipeline.shared.recordingFilterFamily

        let available = FilterLibrary.shared.availableFilters(
            isFront: isFront,
            recordingFamily: recordingFamily,
            isRecording: isRecording
        )

        currentIndex = available.firstIndex(where: { $0.shaderName == currentFragment }) ?? 0
    }

    private func pipeline(for fragment: String) -> MTLRenderPipelineState {
        if let cached = pipelines[fragment] { return cached }

        guard let vertex = library.makeFunction(name: "vertex_main") else {
            fatalError("❌ Missing vertex_main")
        }

        let fragmentName = (library.makeFunction(name: fragment) != nil) ? fragment : "fragment_passthrough"
        guard let frag = library.makeFunction(name: fragmentName) else {
            fatalError("❌ Missing fragment function: \(fragmentName)")
        }

        let desc = MTLRenderPipelineDescriptor()
        desc.vertexFunction = vertex
        desc.fragmentFunction = frag
        desc.colorAttachments[0].pixelFormat = .bgra8Unorm

        do {
            let ps = try device.makeRenderPipelineState(descriptor: desc)
            pipelines[fragment] = ps
            return ps
        } catch {
            fatalError("❌ Failed to build pipeline for \(fragment): \(error)")
        }
    }
}
extension ShaderManager {
    func selectShader(by fragment: String) { select(fragment: fragment) }
    func selectShader(_ fragment: String) { select(fragment: fragment) }
}
