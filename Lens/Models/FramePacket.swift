//
//  FramePacket.swift
//  Lens
//
//  Created by Филипп Герасимов on 11/02/26.
//

import CoreVideo
import CoreMedia

struct FramePacket {
    let pixelBuffer: CVPixelBuffer
    let time: CMTime
}
