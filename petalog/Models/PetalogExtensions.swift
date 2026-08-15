import Foundation
import ImageIO
import UIKit

extension Date {
    nonisolated var petalogDateKey: String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: self)
    }

    nonisolated var petalogDisplayDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日 EEEE"
        return formatter.string(from: self)
    }

    nonisolated var petalogShortTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M/d"
        return "\(formatter.string(from: self)) の絵日記"
    }
}

extension String {
    var trimmedForPetalog: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

extension Data {
    /// Creates a phone-friendly JPEG without first decoding the full-resolution
    /// source into a large UIKit bitmap. The original data is returned only if
    /// the input cannot be decoded as an image.
    func petalogOptimizedJPEG(
        maxDimension: Int = 1_800,
        quality: CGFloat = 0.78,
        maximumBytes: Int = 1_500_000
    ) -> Data {
        guard let source = CGImageSourceCreateWithData(self as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(
                source,
                0,
                [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: maxDimension
                ] as CFDictionary
              ) else {
            return self
        }

        let uiImage = UIImage(cgImage: image)
        var currentQuality = quality
        var result = uiImage.jpegData(compressionQuality: currentQuality) ?? self

        while result.count > maximumBytes && currentQuality > 0.52 {
            currentQuality -= 0.05
            result = uiImage.jpegData(compressionQuality: currentQuality) ?? result
        }
        return result
    }
}

extension UIImage {
    /// Reduces camera working-set size before the image reaches the editor.
    func petalogResized(maxDimension: CGFloat) -> UIImage {
        guard let cgImage,
              CGFloat(max(cgImage.width, cgImage.height)) > maxDimension else { return self }

        let ratio = maxDimension / CGFloat(max(cgImage.width, cgImage.height))
        let size = CGSize(
            width: CGFloat(cgImage.width) * ratio,
            height: CGFloat(cgImage.height) * ratio
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
