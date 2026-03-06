import Foundation

enum CaptureKind: String, Codable {
  case photo
  case video
}

struct CaptureItem: Identifiable, Codable, Hashable {
  let id: UUID
  let kind: CaptureKind
  let createdAt: Date
  let localPath: String?  // позже сюда положишь путь к файлу в Documents
}

struct EffectItem: Identifiable, Codable, Hashable {
  let id: UUID
  let title: String
  let subtitle: String?
  let shaderKey: String  // ключ/enum для ShaderManager
}
