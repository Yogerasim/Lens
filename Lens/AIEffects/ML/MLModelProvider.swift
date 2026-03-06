import CoreML

final class MLModelProvider {

  let model: MLModel

  init() throws {
    let config = MLModelConfiguration()
    config.computeUnits = .all
    config.allowLowPrecisionAccumulationOnGPU = true

    self.model = try MLModel(
      contentsOf: URL(fileURLWithPath: "")
    )
  }
}
