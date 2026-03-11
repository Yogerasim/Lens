import Foundation
import UIKit
internal import AVFoundation

protocol CapturePreviewStorageServiceProtocol {
    func storePhotoData(_ data: Data) async throws -> CapturedMedia
    func storeVideoFile(from sourceURL: URL) async throws -> CapturedMedia
    func deleteMedia(_ media: CapturedMedia) throws
    func cleanupTemporaryDirectory() throws
}

final class CapturePreviewStorageService: CapturePreviewStorageServiceProtocol {
    
    private let fileManager: FileManager
    private let temporaryDirectory: URL
    
    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        
        let baseTemp = fileManager.temporaryDirectory
        self.temporaryDirectory = baseTemp.appendingPathComponent("CapturePreview", isDirectory: true)
        
        createDirectoryIfNeeded()
    }
    
    func storePhotoData(_ data: Data) async throws -> CapturedMedia {
        let fileURL = temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("jpg")
        
        try data.write(to: fileURL, options: .atomic)
        
        let image = UIImage(data: data)
        let previewData = image?.jpegData(compressionQuality: 0.7)
        let fileSize = try fileSizeBytes(at: fileURL)
        
        return CapturedMedia(
            type: .photo,
            fileURL: fileURL,
            previewImageData: previewData,
            metadata: .init(
                pixelSize: image.map { CGSize(width: $0.size.width, height: $0.size.height) },
                duration: nil,
                fileSizeBytes: fileSize
            )
        )
    }
    
    func storeVideoFile(from sourceURL: URL) async throws -> CapturedMedia {
        let fileURL = temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(sourceURL.pathExtension.isEmpty ? "mov" : sourceURL.pathExtension)
        
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
        
        try fileManager.copyItem(at: sourceURL, to: fileURL)
        
        let asset = AVURLAsset(url: fileURL)
        let duration = try await asset.load(.duration).seconds
        
        let previewData = try await generateThumbnailData(for: fileURL)
        let fileSize = try fileSizeBytes(at: fileURL)
        
        return CapturedMedia(
            type: .video,
            fileURL: fileURL,
            previewImageData: previewData,
            metadata: .init(
                pixelSize: nil,
                duration: duration.isFinite ? duration : nil,
                fileSizeBytes: fileSize
            )
        )
    }
    
    func deleteMedia(_ media: CapturedMedia) throws {
        guard fileManager.fileExists(atPath: media.fileURL.path) else { return }
        try fileManager.removeItem(at: media.fileURL)
    }
    
    func cleanupTemporaryDirectory() throws {
        guard fileManager.fileExists(atPath: temporaryDirectory.path) else { return }
        let items = try fileManager.contentsOfDirectory(at: temporaryDirectory, includingPropertiesForKeys: nil)
        for item in items {
            try? fileManager.removeItem(at: item)
        }
    }
    
    private func createDirectoryIfNeeded() {
        guard !fileManager.fileExists(atPath: temporaryDirectory.path) else { return }
        try? fileManager.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    }
    
    private func fileSizeBytes(at url: URL) throws -> Int64 {
        let values = try url.resourceValues(forKeys: [.fileSizeKey])
        return Int64(values.fileSize ?? 0)
    }
    
    private func generateThumbnailData(for videoURL: URL) async throws -> Data? {
        let asset = AVAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        
        let cgImage = try generator.copyCGImage(at: .zero, actualTime: nil)
        let image = UIImage(cgImage: cgImage)
        return image.jpegData(compressionQuality: 0.7)
    }
}
