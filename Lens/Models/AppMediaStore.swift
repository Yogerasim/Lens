import Combine
import Foundation

final class AppMediaStore: ObservableObject {

  @Published var captures: [CaptureItem] = [
    .init(id: UUID(), kind: .photo, createdAt: Date().addingTimeInterval(-3600), localPath: nil),
    .init(id: UUID(), kind: .video, createdAt: Date().addingTimeInterval(-7200), localPath: nil),
    .init(id: UUID(), kind: .photo, createdAt: Date().addingTimeInterval(-86000), localPath: nil),
  ]

  @Published var effects: [EffectItem] = [
    .init(id: UUID(), title: "Glass Blur", subtitle: "Мягкое стекло", shaderKey: "glass_blur"),
    .init(id: UUID(), title: "Pixel", subtitle: "Пикселизация", shaderKey: "pixel"),
    .init(id: UUID(), title: "Neon", subtitle: "Неоновые края", shaderKey: "neon"),
    .init(id: UUID(), title: "B/W", subtitle: "Ч/Б классика", shaderKey: "bw"),
  ]
}
