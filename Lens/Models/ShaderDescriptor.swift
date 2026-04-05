struct ShaderDescriptor: Identifiable, Hashable {
  let id: String
  let displayName: String
  let fragment: String
  let icon: String
  let needsDepth: Bool
  let supportsIntensity: Bool
  let family: FilterFamily
  let category: EffectCardCategory
  let isPremium: Bool
  let previewImageName: String?

  init(
    id: String,
    displayName: String,
    fragment: String,
    icon: String,
    needsDepth: Bool,
    supportsIntensity: Bool,
    family: FilterFamily,
    category: EffectCardCategory,
    isPremium: Bool = false,
    previewImageName: String? = nil
  ) {
    self.id = id
    self.displayName = displayName
    self.fragment = fragment
    self.icon = icon
    self.needsDepth = needsDepth
    self.supportsIntensity = supportsIntensity
    self.family = family
    self.category = category
    self.isPremium = isPremium
    self.previewImageName = previewImageName ?? id
  }
}
