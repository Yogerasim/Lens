enum ShaderRegistry {
    static let all: [ShaderDescriptor] = [
        .init(id: "comic", displayName: "Comic", fragment: "fragment_comic",
              icon: "paintbrush.fill", needsDepth: false, supportsIntensity: true, family: .nonDepth),

        .init(id: "techLines", displayName: "Tech Lines", fragment: "fragment_techlines",
              icon: "line.3.crossed.swirl.circle.fill", needsDepth: false, supportsIntensity: true, family: .nonDepth),

        .init(id: "acidTrip", displayName: "Acid Trip", fragment: "fragment_acidtrip",
              icon: "sparkles", needsDepth: false, supportsIntensity: true, family: .nonDepth),

        .init(id: "neuralPainter", displayName: "Neural Painter", fragment: "fragment_neuralpainter",
              icon: "brain.head.profile", needsDepth: false, supportsIntensity: true, family: .nonDepth),

        .init(id: "depthFog", displayName: "Depth Fog", fragment: "fragment_depthfog",
              icon: "cloud.fog.fill", needsDepth: true, supportsIntensity: true, family: .depth),

        .init(id: "depthOutline", displayName: "Depth Outline", fragment: "fragment_depthoutline",
              icon: "cube.transparent", needsDepth: true, supportsIntensity: true, family: .depth),

        .init(id: "depthThermal", displayName: "Depth Thermal", fragment: "fragment_depththermal",
              icon: "thermometer.sun.fill", needsDepth: true, supportsIntensity: true, family: .depth),

        .init(id: "customGraph", displayName: "Custom Graph", fragment: "fragment_universalgraph",
              icon: "square.stack.3d.up.fill", needsDepth: false, supportsIntensity: true, family: .nonDepth),
    ]
}
extension ShaderRegistry {
    static let customGraphFragment = "fragment_universalgraph"
}
