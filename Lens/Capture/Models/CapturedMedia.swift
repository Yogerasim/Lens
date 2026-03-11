import Foundation
import UIKit

enum CapturedMediaType: Sendable {
    case photo
    case video
}

struct CapturedMediaMetadata: Sendable {
    let pixelSize: CGSize?
    let duration: TimeInterval?
    let fileSizeBytes: Int64?
    
    init(
        pixelSize: CGSize? = nil,
        duration: TimeInterval? = nil,
        fileSizeBytes: Int64? = nil
    ) {
        self.pixelSize = pixelSize
        self.duration = duration
        self.fileSizeBytes = fileSizeBytes
    }
}

struct CapturedMedia: Identifiable, Sendable {
    let id: UUID
    let type: CapturedMediaType
    let fileURL: URL
    let previewImageData: Data?
    let createdAt: Date
    let metadata: CapturedMediaMetadata
    
    init(
        id: UUID = UUID(),
        type: CapturedMediaType,
        fileURL: URL,
        previewImageData: Data? = nil,
        createdAt: Date = Date(),
        metadata: CapturedMediaMetadata = .init()
    ) {
        self.id = id
        self.type = type
        self.fileURL = fileURL
        self.previewImageData = previewImageData
        self.createdAt = createdAt
        self.metadata = metadata
    }
    
    var previewImage: UIImage? {
        guard let previewImageData else { return nil }
        return UIImage(data: previewImageData)
    }
}
