import Foundation

enum EffectCardCategory: String, CaseIterable, Codable, Hashable {
  case pro
  case depth
  case outline
  case stylized
  case myEffects

  var title: String {
    switch self {
    case .stylized: return "Stylized"
    case .pro: return "PRO"
    case .depth: return "LiDAR"
    case .outline: return "Outline"
    case .myEffects: return "My Effects"
    }
  }
}

enum ShaderRegistry {
  static let all: [ShaderDescriptor] = [

    // MARK: - PRO

    .init(
      id: "kaleidoscope",
      displayName: "Kaleidoscope Pro",
      fragment: "fragment_kaleidoscope",
      icon: "hexagon.grid.fill",
      needsDepth: false,
      supportsIntensity: true,
      family: .nonDepth,
      category: .pro,
      isPremium: true
    ),

    .init(
      id: "infraredBloom",
      displayName: "Infrared Bloom",
      fragment: "fragment_infraredbloom",
      icon: "camera.aperture",
      needsDepth: false,
      supportsIntensity: true,
      family: .nonDepth,
      category: .pro,
      isPremium: true
    ),

    .init(
      id: "chromeGhost",
      displayName: "Chrome Ghost",
      fragment: "fragment_chromeghost",
      icon: "sparkles.rectangle.stack.fill",
      needsDepth: false,
      supportsIntensity: true,
      family: .nonDepth,
      category: .pro,
      isPremium: true
    ),

    .init(
      id: "posterBurnUltra",
      displayName: "Poster Burn Ultra",
      fragment: "fragment_posterburnultra",
      icon: "sparkles.tv.fill",
      needsDepth: false,
      supportsIntensity: true,
      family: .nonDepth,
      category: .pro,
      isPremium: true
    ),

    .init(
      id: "gyroidSerpentUltra",
      displayName: "Gyroid Serpent Ultra",
      fragment: "fragment_gyroidserpentultra",
      icon: "wave.3.right.circle.fill",
      needsDepth: false,
      supportsIntensity: true,
      family: .nonDepth,
      category: .pro,
      isPremium: true
    ),

    .init(
      id: "shineTunnelOilSlick",
      displayName: "Shine Tunnel Oil Slick",
      fragment: "fragment_shinetunneloilslick",
      icon: "sparkles.tv.fill",
      needsDepth: false,
      supportsIntensity: true,
      family: .nonDepth,
      category: .pro,
      isPremium: true
    ),

    // MARK: - DEPTH / LiDAR

    .init(
      id: "depthSolidMono",
      displayName: "Depth Solid Mono",
      fragment: "fragment_depthsolidmono",
      icon: "cube.fill",
      needsDepth: true,
      supportsIntensity: true,
      family: .depth,
      category: .depth
    ),

    .init(
      id: "depthCAD",
      displayName: "Depth CAD",
      fragment: "fragment_depthcad",
      icon: "square.3.layers.3d",
      needsDepth: true,
      supportsIntensity: true,
      family: .depth,
      category: .depth
    ),

    .init(
      id: "depthSolidThermal",
      displayName: "Depth Solid Thermal",
      fragment: "fragment_depthsolidthermal",
      icon: "flame.fill",
      needsDepth: true,
      supportsIntensity: true,
      family: .depth,
      category: .depth
    ),

    .init(
      id: "depthSolid",
      displayName: "Depth Solid",
      fragment: "fragment_depthsolid",
      icon: "cube.fill",
      needsDepth: true,
      supportsIntensity: true,
      family: .depth,
      category: .depth
    ),

    .init(
      id: "depthOutline",
      displayName: "Depth Outline",
      fragment: "fragment_depthoutline",
      icon: "cube.transparent",
      needsDepth: true,
      supportsIntensity: true,
      family: .depth,
      category: .depth
    ),

    .init(
      id: "depthIridescent",
      displayName: "Night Vision",
      fragment: "fragment_depthiridescent",
      icon: "sparkle.magnifyingglass",
      needsDepth: true,
      supportsIntensity: true,
      family: .depth,
      category: .depth
    ),

    // MARK: - OUTLINE

    .init(
      id: "comic",
      displayName: "Comic",
      fragment: "fragment_comic",
      icon: "paintbrush.fill",
      needsDepth: false,
      supportsIntensity: true,
      family: .nonDepth,
      category: .outline
    ),

    .init(
      id: "neonEdge",
      displayName: "Neon Edge",
      fragment: "fragment_neonedge",
      icon: "bolt.circle.fill",
      needsDepth: false,
      supportsIntensity: true,
      family: .nonDepth,
      category: .outline
    ),

    .init(
      id: "techLines",
      displayName: "Tech Lines",
      fragment: "fragment_techlines",
      icon: "line.3.crossed.swirl.circle.fill",
      needsDepth: false,
      supportsIntensity: true,
      family: .nonDepth,
      category: .outline
    ),

    .init(
      id: "negativeOutline",
      displayName: "Negative Outline",
      fragment: "fragment_negativeoutline",
      icon: "moon.stars.fill",
      needsDepth: false,
      supportsIntensity: true,
      family: .nonDepth,
      category: .outline
    ),

    .init(
      id: "sepiaInk",
      displayName: "Sepia Ink",
      fragment: "fragment_sepiaink",
      icon: "pencil.and.outline",
      needsDepth: false,
      supportsIntensity: true,
      family: .nonDepth,
      category: .outline
    ),

    .init(
      id: "mangaBW",
      displayName: "Manga BW",
      fragment: "fragment_mangabw",
      icon: "circle.grid.cross.fill",
      needsDepth: false,
      supportsIntensity: true,
      family: .nonDepth,
      category: .outline
    ),

    .init(
      id: "xeroxPunk",
      displayName: "Xerox Punk",
      fragment: "fragment_xeroxpunk",
      icon: "doc.richtext.fill",
      needsDepth: false,
      supportsIntensity: true,
      family: .nonDepth,
      category: .outline
    ),

    .init(
      id: "classicNegative",
      displayName: "Classic Negative",
      fragment: "fragment_classicnegative",
      icon: "circle.righthalf.pattern.checkered",
      needsDepth: false,
      supportsIntensity: true,
      family: .nonDepth,
      category: .outline
    ),

    .init(
      id: "whitePencil",
      displayName: "White Pencil",
      fragment: "fragment_whitepencil",
      icon: "pencil.tip.crop.circle",
      needsDepth: false,
      supportsIntensity: true,
      family: .nonDepth,
      category: .outline
    ),

    .init(
      id: "thermalComic",
      displayName: "Thermal Comic",
      fragment: "fragment_thermalcomic",
      icon: "thermometer.sun.fill",
      needsDepth: false,
      supportsIntensity: true,
      family: .nonDepth,
      category: .outline
    ),

    .init(
      id: "newsprint",
      displayName: "Newsprint",
      fragment: "fragment_newsprint",
      icon: "newspaper.fill",
      needsDepth: false,
      supportsIntensity: true,
      family: .nonDepth,
      category: .outline
    ),

    .init(
      id: "blueprintInk",
      displayName: "Blueprint Ink",
      fragment: "fragment_blueprintink",
      icon: "pencil.and.ruler.fill",
      needsDepth: false,
      supportsIntensity: true,
      family: .nonDepth,
      category: .outline
    ),

    // MARK: - STYLIZED

    .init(
      id: "vhsAnalog",
      displayName: "VHS Analog",
      fragment: "fragment_vhsanalog",
      icon: "tv.fill",
      needsDepth: false,
      supportsIntensity: true,
      family: .nonDepth,
      category: .stylized
    ),

    .init(
      id: "dotMatrix",
      displayName: "Dot Matrix",
      fragment: "fragment_dotmatrix",
      icon: "circle.grid.3x3.fill",
      needsDepth: false,
      supportsIntensity: true,
      family: .nonDepth,
      category: .stylized
    ),

    .init(
      id: "rgbSplit",
      displayName: "RGB Split",
      fragment: "fragment_rgbsplit",
      icon: "circle.lefthalf.filled",
      needsDepth: false,
      supportsIntensity: true,
      family: .nonDepth,
      category: .stylized
    ),

    .init(
      id: "hologram",
      displayName: "Hologram",
      fragment: "fragment_hologram",
      icon: "sparkles",
      needsDepth: false,
      supportsIntensity: true,
      family: .nonDepth,
      category: .stylized
    ),

    .init(
      id: "pixelBlocks",
      displayName: "Pixel Blocks",
      fragment: "fragment_pixelblocks",
      icon: "square.grid.3x3.fill",
      needsDepth: false,
      supportsIntensity: true,
      family: .nonDepth,
      category: .stylized
    ),

    .init(
      id: "scanlines",
      displayName: "Scanlines",
      fragment: "fragment_scanlines",
      icon: "waveform",
      needsDepth: false,
      supportsIntensity: true,
      family: .nonDepth,
      category: .stylized
    ),

    .init(
      id: "ripple",
      displayName: "Ripple",
      fragment: "fragment_ripple",
      icon: "drop.fill",
      needsDepth: false,
      supportsIntensity: true,
      family: .nonDepth,
      category: .stylized
    ),

    .init(
      id: "acidTrip",
      displayName: "Acid Trip",
      fragment: "fragment_acidtrip",
      icon: "sparkles",
      needsDepth: false,
      supportsIntensity: true,
      family: .nonDepth,
      category: .stylized
    ),

    .init(
      id: "neuralPainter",
      displayName: "Neural Painter",
      fragment: "fragment_neuralpainter",
      icon: "brain.head.profile",
      needsDepth: false,
      supportsIntensity: true,
      family: .nonDepth,
      category: .stylized
    ),

    .init(
      id: "solidMono",
      displayName: "Solid Mono",
      fragment: "fragment_solidmono",
      icon: "circle.lefthalf.filled",
      needsDepth: false,
      supportsIntensity: true,
      family: .nonDepth,
      category: .stylized
    ),

    .init(
      id: "posterBurn",
      displayName: "Poster Burn",
      fragment: "fragment_posterburn",
      icon: "flame.circle.fill",
      needsDepth: false,
      supportsIntensity: true,
      family: .nonDepth,
      category: .stylized
    ),

    .init(
      id: "xrayPop",
      displayName: "X-Ray Pop",
      fragment: "fragment_xraypop",
      icon: "eye.fill",
      needsDepth: false,
      supportsIntensity: true,
      family: .nonDepth,
      category: .stylized
    ),

    .init(
      id: "signalLoss",
      displayName: "Signal Loss",
      fragment: "fragment_signalloss",
      icon: "wifi.exclamationmark",
      needsDepth: false,
      supportsIntensity: true,
      family: .nonDepth,
      category: .stylized
    ),

    .init(
      id: "shineTunnel",
      displayName: "Shine Tunnel",
      fragment: "fragment_shinetunnel",
      icon: "sparkles.tv.fill",
      needsDepth: false,
      supportsIntensity: true,
      family: .nonDepth,
      category: .stylized
    ),

    .init(
      id: "gyroidSerpent",
      displayName: "Gyroid Serpent",
      fragment: "fragment_gyroidserpent",
      icon: "wave.3.right.circle.fill",
      needsDepth: false,
      supportsIntensity: true,
      family: .nonDepth,
      category: .stylized
    ),

    // MARK: - Commented / parked effects

//    .init(
//      id: "chromeReflect",
//      displayName: "Chrome Reflect",
//      fragment: "fragment_chromereflect",
//      icon: "sparkle.magnifyingglass",
//      needsDepth: false,
//      supportsIntensity: true,
//      family: .nonDepth,
//      category: .stylized
//    ),

//    .init(
//      id: "heatDistort",
//      displayName: "Heat Distortion",
//      fragment: "fragment_heatdistort",
//      icon: "flame.fill",
//      needsDepth: false,
//      supportsIntensity: true,
//      family: .nonDepth,
//      category: .stylized
//    ),

//    .init(
//      id: "liquidGlass",
//      displayName: "Liquid Glass",
//      fragment: "fragment_liquidglass",
//      icon: "drop.fill",
//      needsDepth: false,
//      supportsIntensity: true,
//      family: .nonDepth,
//      category: .stylized
//    ),

//    .init(
//      id: "dotMatrixDepth",
//      displayName: "Dot Matrix Depth",
//      fragment: "fragment_dotmatrixdepth",
//      icon: "circle.grid.cross.fill",
//      needsDepth: false,
//      supportsIntensity: true,
//      family: .nonDepth,
//      category: .stylized
//    ),

//    .init(
//      id: "crtGlass",
//      displayName: "CRT Glass",
//      fragment: "fragment_crtglass",
//      icon: "tv.fill",
//      needsDepth: false,
//      supportsIntensity: true,
//      family: .nonDepth,
//      category: .stylized
//    ),

//    .init(
//      id: "prismMelt",
//      displayName: "Prism Melt",
//      fragment: "fragment_prismmelt",
//      icon: "diamond.fill",
//      needsDepth: false,
//      supportsIntensity: true,
//      family: .nonDepth,
//      category: .stylized
//    ),

//    .init(
//      id: "holoFoil",
//      displayName: "Holo Foil",
//      fragment: "fragment_holofoil",
//      icon: "sparkles",
//      needsDepth: false,
//      supportsIntensity: true,
//      family: .nonDepth,
//      category: .stylized
//    ),

//    .init(
//      id: "nightOps",
//      displayName: "Night Ops",
//      fragment: "fragment_nightops",
//      icon: "moon.fill",
//      needsDepth: false,
//      supportsIntensity: true,
//      family: .nonDepth,
//      category: .stylized
//    ),

//    .init(
//      id: "pearlShift",
//      displayName: "Pearl Shift",
//      fragment: "fragment_pearlshift",
//      icon: "sparkle.magnifyingglass",
//      needsDepth: false,
//      supportsIntensity: true,
//      family: .nonDepth,
//      category: .stylized
//    ),

//    .init(
//      id: "electricAura",
//      displayName: "Electric Aura",
//      fragment: "fragment_electricaura",
//      icon: "bolt.fill",
//      needsDepth: false,
//      supportsIntensity: true,
//      family: .nonDepth,
//      category: .stylized
//    ),

//    .init(
//      id: "mercury",
//      displayName: "Mercury",
//      fragment: "fragment_mercury",
//      icon: "circle.hexagongrid.fill",
//      needsDepth: false,
//      supportsIntensity: true,
//      family: .nonDepth,
//      category: .stylized
//    ),

//    .init(
//      id: "matrix",
//      displayName: "Matrix",
//      fragment: "fragment_matrix",
//      icon: "textformat.abc",
//      needsDepth: false,
//      supportsIntensity: true,
//      family: .nonDepth,
//      category: .stylized
//    ),

//    .init(
//      id: "depthGrid",
//      displayName: "Depth Grid",
//      fragment: "fragment_depthgrid",
//      icon: "grid",
//      needsDepth: true,
//      supportsIntensity: true,
//      family: .depth,
//      category: .depth
//    ),

//    .init(
//      id: "depthFog",
//      displayName: "Depth Fog",
//      fragment: "fragment_depthfog",
//      icon: "cloud.fog.fill",
//      needsDepth: true,
//      supportsIntensity: true,
//      family: .depth,
//      category: .depth
//    ),

//    .init(
//      id: "depthThermal",
//      displayName: "Depth Thermal",
//      fragment: "fragment_depththermal",
//      icon: "thermometer.sun.fill",
//      needsDepth: true,
//      supportsIntensity: true,
//      family: .depth,
//      category: .depth
//    ),

//    .init(
//      id: "depthComicThermal",
//      displayName: "Depth Comic Thermo",
//      fragment: "fragment_depthcomicthermal",
//      icon: "camera.filters",
//      needsDepth: true,
//      supportsIntensity: true,
//      family: .depth,
//      category: .depth
//    ),

//    .init(
//      id: "customGraph",
//      displayName: "Custom Graph",
//      fragment: "fragment_universalgraph",
//      icon: "square.stack.3d.up.fill",
//      needsDepth: false,
//      supportsIntensity: true,
//      family: .nonDepth,
//      category: .myEffects
//    ),
  ]
}

extension ShaderRegistry {
  static let customGraphFragment = "fragment_universalgraph"

  static func descriptor(for fragment: String) -> ShaderDescriptor? {
    all.first { $0.fragment == fragment }
  }

  static func descriptor(forID id: String) -> ShaderDescriptor? {
    all.first { $0.id == id }
  }

  static func descriptors(for category: EffectCardCategory) -> [ShaderDescriptor] {
    all.filter { $0.category == category }
  }
}
