import Foundation
import SwiftUI
import Combine

@MainActor
final class CapturePreviewViewModel: ObservableObject {
    
    enum SaveState: Equatable {
        case idle
        case saving
        case saved
        case failed(String)
    }
    
    @Published private(set) var media: CapturedMedia
    @Published private(set) var preparedAsset: PreparedShareAsset?
    @Published private(set) var saveState: SaveState = .idle
    @Published var shareItems: [Any] = []
    @Published var isShowingShareSheet = false
    @Published var errorMessage: String?
    
    private let saveService: MediaSaveServiceProtocol
    private let shareService: MediaShareServiceProtocol
    private let preparationService: MediaPreparationServiceProtocol
    private let storageService: CapturePreviewStorageServiceProtocol
    
    init(
        media: CapturedMedia,
        saveService: MediaSaveServiceProtocol = MediaSaveService(),
        shareService: MediaShareServiceProtocol = MediaShareService(),
        preparationService: MediaPreparationServiceProtocol = MediaPreparationService(),
        storageService: CapturePreviewStorageServiceProtocol = CapturePreviewStorageService()
    ) {
        self.media = media
        self.saveService = saveService
        self.shareService = shareService
        self.preparationService = preparationService
        self.storageService = storageService
    }
    
    func onAppear() {
        guard preparedAsset == nil else { return }
        
        Task {
            do {
                preparedAsset = try await preparationService.prepareForSharing(media)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    func saveToGallery() {
        Task {
            saveState = .saving
            
            do {
                try await saveService.saveToPhotoLibrary(media)
                saveState = .saved
            } catch {
                saveState = .failed(error.localizedDescription)
                errorMessage = error.localizedDescription
            }
        }
    }
    
    func share() {
        Task {
            do {
                let asset = try await preparationService.prepareForSharing(media)
                preparedAsset = asset
                shareItems = shareService.makeShareItems(for: asset)
                isShowingShareSheet = true
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    func closeAndDeleteTemporaryMedia() {
        do {
            try storageService.deleteMedia(media)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
