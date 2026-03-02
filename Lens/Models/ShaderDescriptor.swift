struct ShaderDescriptor: Identifiable, Hashable {
    let id: String              // стабильный ключ, напр. "depthThermal"
    let displayName: String     // "Depth Thermal"
    let fragment: String        // "fragment_depththermal"
    let icon: String            // SF Symbol
    let needsDepth: Bool
    let supportsIntensity: Bool
    let family: FilterFamily    // .depth / .nonDepth (можно вычислять из needsDepth)
}
