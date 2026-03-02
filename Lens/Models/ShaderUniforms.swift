import Foundation

/// Должно 1-в-1 совпадать по полям и порядку с `struct Uniforms` в .metal
struct ShaderUniforms {
    var time: Float
    var viewAspect: Float
    var textureAspect: Float
    var rotation: Float
    var mirror: Float
    var hasDepth: Float
    var depthFlipX: Float
    var depthFlipY: Float
    var intensity: Float
    var effectiveTextureAspect: Float
    var uvScaleX: Float
    var uvScaleY: Float
}
