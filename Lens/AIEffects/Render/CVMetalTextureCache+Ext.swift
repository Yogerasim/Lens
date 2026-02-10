import Metal
import CoreVideo

final class TextureCache {

    static let shared = TextureCache()

    let cache: CVMetalTextureCache

    private init() {
        var cache: CVMetalTextureCache?
        CVMetalTextureCacheCreate(
            kCFAllocatorDefault,
            nil,
            MetalContext.shared.device,
            nil,
            &cache
        )
        self.cache = cache!
    }
}
