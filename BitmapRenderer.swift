import SwiftUI
import CoreGraphics

enum PixelFormat: String, CaseIterable, Identifiable {
    case grayscale = "Grayscale (8-bit)"
    case rgb = "RGB (24-bit)"
    case rgba = "RGBA (32-bit)"
    
    var id: String { rawValue }
    
    var bytesPerPixel: Int {
        switch self {
        case .grayscale: return 1
        case .rgb: return 3
        case .rgba: return 4
        }
    }
}

class BitmapRenderer {
    static func render(buffer: GapBuffer, width: Int, format: PixelFormat) -> CGImage? {
        guard width > 0 else { return nil }
        
        let bytesPerPixel = format.bytesPerPixel
        let totalBytes = buffer.count
        let height = (totalBytes + (width * bytesPerPixel) - 1) / (width * bytesPerPixel)
        
        guard height > 0 else { return nil }
        
        // Prepare data
        // For performance, we might want to access buffer directly, but GapBuffer is split.
        // Let's convert to Data for now.
        let data = buffer.toData()
        
        // We need a contiguous buffer for CGImage
        // If format is RGB (3 bytes), CoreGraphics usually prefers RGBA (4 bytes) or specific alignments.
        // But we can try to use raw data if we set parameters right.
        // Grayscale (8-bit) is easy.
        // RGBA (32-bit) is easy.
        // RGB (24-bit) is supported but might be slower or require specific alignment.
        
        var renderData = data
        
        // Pad data if necessary to fill the last row
        let requiredBytes = width * height * bytesPerPixel
        if renderData.count < requiredBytes {
            renderData.append(Data(repeating: 0, count: requiredBytes - renderData.count))
        }
        
        let colorSpace: CGColorSpace
        let bitmapInfo: CGBitmapInfo
        
        switch format {
        case .grayscale:
            colorSpace = CGColorSpaceCreateDeviceGray()
            bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
        case .rgb:
            colorSpace = CGColorSpaceCreateDeviceRGB()
            bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
        case .rgba:
            colorSpace = CGColorSpaceCreateDeviceRGB()
            bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        }
        
        guard let provider = CGDataProvider(data: renderData as CFData) else { return nil }
        
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 8 * bytesPerPixel,
            bytesPerRow: width * bytesPerPixel,
            space: colorSpace,
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }
}
