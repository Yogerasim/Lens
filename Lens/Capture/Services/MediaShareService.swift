import Foundation
import UIKit
import SwiftUI

protocol MediaShareServiceProtocol {
    func makeShareItems(for asset: PreparedShareAsset) -> [Any]
}

final class MediaShareService: MediaShareServiceProtocol {
    
    func makeShareItems(for asset: PreparedShareAsset) -> [Any] {
        [asset.exportURL]
    }
}
