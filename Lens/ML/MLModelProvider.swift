import CoreML

final class MLModelProvider {

    let model: MLModel

    init() throws {
        let config = MLModelConfiguration()
        config.computeUnits = .all
        config.allowLowPrecisionAccumulationOnGPU = true

        // ⚠️ ЗАГЛУШКА
        self.model = try MLModel(
            contentsOf: URL(fileURLWithPath: "")
        )
    }
}
