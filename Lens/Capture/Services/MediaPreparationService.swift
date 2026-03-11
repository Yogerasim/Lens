import Foundation

protocol MediaPreparationServiceProtocol {
    func prepareForSharing(_ media: CapturedMedia) async throws -> PreparedShareAsset
}

final class MediaPreparationService: MediaPreparationServiceProtocol {
    
    func prepareForSharing(_ media: CapturedMedia) async throws -> PreparedShareAsset {
        PreparedShareAsset(
            media: media,
            exportURL: media.fileURL,
            thumbnailData: media.previewImageData,
            isReadyForSharing: true
        )
    }
}
