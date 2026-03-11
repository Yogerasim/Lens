import Foundation
import Photos

protocol MediaSaveServiceProtocol {
    func saveToPhotoLibrary(_ media: CapturedMedia) async throws
}

enum MediaSaveError: LocalizedError {
    case unauthorized
    case unsupported
    
    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "No access to Photo Library."
        case .unsupported:
            return "Unsupported media type."
        }
    }
}

final class MediaSaveService: MediaSaveServiceProtocol {
    
    func saveToPhotoLibrary(_ media: CapturedMedia) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        
        guard status == .authorized || status == .limited else {
            throw MediaSaveError.unauthorized
        }
        
        try await PHPhotoLibrary.shared().performChanges {
            switch media.type {
            case .photo:
                PHAssetCreationRequest.forAsset().addResource(with: .photo, fileURL: media.fileURL, options: nil)
            case .video:
                PHAssetCreationRequest.forAsset().addResource(with: .video, fileURL: media.fileURL, options: nil)
            }
        }
    }
}
