import Foundation
import UIKit

struct PreparedShareAsset: Sendable {
    let media: CapturedMedia
    let exportURL: URL
    let thumbnailData: Data?
    let isReadyForSharing: Bool
    
    init(
        media: CapturedMedia,
        exportURL: URL,
        thumbnailData: Data? = nil,
        isReadyForSharing: Bool = true
    ) {
        self.media = media
        self.exportURL = exportURL
        self.thumbnailData = thumbnailData
        self.isReadyForSharing = isReadyForSharing
    }
    
    var thumbnailImage: UIImage? {
        guard let thumbnailData else { return nil }
        return UIImage(data: thumbnailData)
    }
}
