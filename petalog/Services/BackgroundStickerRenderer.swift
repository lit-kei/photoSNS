import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

enum BackgroundStickerRenderer {
    static let canvasSize = CGSize(width: 512, height: 512)
    static let scaleRange = 0.55...2.2

    private static let context = CIContext(options: [.cacheIntermediates: false])

    static func prepareForeground(
        _ foreground: UIImage,
        effect: StickerEffect,
        decoration: StickerDecoration,
        outlineColor: UIColor = .white
    ) throws -> UIImage {
        let source = foreground.petalogResized(maxDimension: 900)
        let filtered = try apply(effect, to: source)
        return try apply(decoration, to: filtered, outlineColor: outlineColor)
    }

    static func renderPNG(preparedForeground: UIImage, draft: StickerDraft) throws -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)
        let image = renderer.image { rendererContext in
            UIColor.clear.setFill()
            rendererContext.fill(CGRect(origin: .zero, size: canvasSize))

            let rect = placementRect(
                imageSize: preparedForeground.size,
                canvasSize: canvasSize,
                scale: draft.foregroundScale,
                offset: draft.foregroundOffset
            )
            let cgContext = rendererContext.cgContext
            cgContext.saveGState()
            cgContext.translateBy(x: rect.midX, y: rect.midY)
            cgContext.rotate(by: CGFloat(draft.foregroundRotation) * .pi / 180)
            preparedForeground.draw(
                in: CGRect(x: -rect.width / 2, y: -rect.height / 2, width: rect.width, height: rect.height)
            )
            cgContext.restoreGState()
        }

        guard let data = image.pngData() else {
            throw PetalogError.message("ステッカー画像を書き出せませんでした。")
        }
        guard data.count <= 2_000_000 else {
            throw PetalogError.message("ステッカー画像が2MBを超えました。装飾を変更してもう一度お試しください。")
        }
        guard let cgImage = image.cgImage,
              cgImage.width == 512,
              cgImage.height == 512 else {
            throw PetalogError.message("ステッカー画像を512pxで作成できませんでした。")
        }
        return data
    }

    static func placementSize(
        imageSize: CGSize,
        canvasSize: CGSize,
        scale: Double
    ) -> CGSize {
        guard imageSize.width > 0, imageSize.height > 0 else { return .zero }
        let available = CGSize(width: canvasSize.width * 0.78, height: canvasSize.height * 0.78)
        let fit = min(available.width / imageSize.width, available.height / imageSize.height)
        let safeScale = CGFloat(scale.clamped(to: scaleRange))
        return CGSize(width: imageSize.width * fit * safeScale, height: imageSize.height * fit * safeScale)
    }

    static func constrainedOffset(
        _ proposed: CGSize,
        imageSize: CGSize,
        canvasSize: CGSize,
        scale: Double,
        rotation: Double
    ) -> CGSize {
        let placed = placementSize(imageSize: imageSize, canvasSize: canvasSize, scale: scale)
        let radians = CGFloat(rotation) * .pi / 180
        let rotatedWidth = abs(placed.width * cos(radians)) + abs(placed.height * sin(radians))
        let rotatedHeight = abs(placed.width * sin(radians)) + abs(placed.height * cos(radians))
        let minimumVisible = min(canvasSize.width, canvasSize.height) * 0.10
        let xLimit = max(0, (canvasSize.width / 2 + rotatedWidth / 2 - minimumVisible) / canvasSize.width)
        let yLimit = max(0, (canvasSize.height / 2 + rotatedHeight / 2 - minimumVisible) / canvasSize.height)
        return CGSize(
            width: proposed.width.finiteOrZero.clamped(to: -xLimit...xLimit),
            height: proposed.height.finiteOrZero.clamped(to: -yLimit...yLimit)
        )
    }

    private static func placementRect(
        imageSize: CGSize,
        canvasSize: CGSize,
        scale: Double,
        offset: CGSize
    ) -> CGRect {
        let size = placementSize(imageSize: imageSize, canvasSize: canvasSize, scale: scale)
        return CGRect(
            x: (canvasSize.width - size.width) / 2 + offset.width * canvasSize.width,
            y: (canvasSize.height - size.height) / 2 + offset.height * canvasSize.height,
            width: size.width,
            height: size.height
        )
    }

    private static func apply(_ effect: StickerEffect, to image: UIImage) throws -> UIImage {
        guard effect != .original else { return image }
        guard let cgImage = image.cgImage else { throw ForegroundExtractionError.invalidImage }
        let input = CIImage(cgImage: cgImage)
        let output: CIImage?

        switch effect {
        case .original:
            output = input
        case .grayscale:
            let filter = CIFilter.photoEffectMono()
            filter.inputImage = input
            output = filter.outputImage
        case .noir:
            let filter = CIFilter.photoEffectNoir()
            filter.inputImage = input
            output = filter.outputImage
        case .sepia:
            let filter = CIFilter.sepiaTone()
            filter.inputImage = input
            filter.intensity = 0.86
            output = filter.outputImage
        case .vivid:
            let filter = CIFilter.colorControls()
            filter.inputImage = input
            filter.saturation = 1.35
            filter.contrast = 1.10
            filter.brightness = 0.02
            output = filter.outputImage
        }

        guard let output,
              let result = context.createCGImage(output.cropped(to: input.extent), from: input.extent) else {
            throw ForegroundExtractionError.renderingFailed
        }
        return UIImage(cgImage: result, scale: 1, orientation: .up)
    }

    private static func apply(_ decoration: StickerDecoration, to image: UIImage, outlineColor: UIColor) throws -> UIImage {
        guard decoration != .none else { return image }
        guard let cgImage = image.cgImage else { throw ForegroundExtractionError.invalidImage }

        let padding: CGFloat = decoration == .shadow ? 70 : 44
        let extent = CGRect(
            x: 0,
            y: 0,
            width: CGFloat(cgImage.width) + padding * 2,
            height: CGFloat(cgImage.height) + padding * 2
        )
        let subject = CIImage(cgImage: cgImage).transformed(
            by: CGAffineTransform(translationX: padding, y: padding)
        )
        let mask = alphaMask(from: subject).cropped(to: extent)
        var layers: [CIImage] = []

        switch decoration {
        case .whiteOutline, .sparkle:
            layers.append(coloredMask(dilate(mask, radius: 15), color: outlineColor, extent: extent))
        case .colorfulOutline:
            layers.append(coloredMask(dilate(mask, radius: 19), color: UIColor(white: 0.32, alpha: 1), extent: extent))
            layers.append(coloredMask(dilate(mask, radius: 9), color: UIColor(white: 0.88, alpha: 1), extent: extent))
        case .shadow:
            let blurred = mask
                .clampedToExtent()
                .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 16])
                .cropped(to: extent)
                .transformed(by: CGAffineTransform(translationX: 0, y: -14))
            layers.append(coloredMask(blurred, color: UIColor.black.withAlphaComponent(0.30), extent: extent))
        case .handDrawn:
            layers.append(coloredMask(dilate(mask, radius: 11), color: UIColor.black.withAlphaComponent(0.72), extent: extent))
        case .none:
            break
        }

        let transparent = CIImage(color: .clear).cropped(to: extent)
        let background = layers.reduce(transparent) { layer, next in
            next.composited(over: layer)
        }
        let combined = subject.composited(over: background).cropped(to: extent)
        guard let output = context.createCGImage(combined, from: extent) else {
            throw ForegroundExtractionError.renderingFailed
        }

        var result = UIImage(cgImage: output, scale: 1, orientation: .up)
        if decoration == .sparkle {
            result = addSparkles(to: result)
        }
        return result
    }

    private static func alphaMask(from image: CIImage) -> CIImage {
        image.applyingFilter(
            "CIColorMatrix",
            parameters: [
                "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 1),
                "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 1),
                "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 1),
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1)
            ]
        )
    }

    private static func dilate(_ mask: CIImage, radius: Double) -> CIImage {
        mask.clampedToExtent()
            .applyingFilter("CIMorphologyMaximum", parameters: [kCIInputRadiusKey: radius])
            .cropped(to: mask.extent)
    }

    private static func coloredMask(_ mask: CIImage, color: UIColor, extent: CGRect) -> CIImage {
        let colorImage = CIImage(color: CIColor(color: color)).cropped(to: extent)
        let transparent = CIImage(color: .clear).cropped(to: extent)
        return colorImage.applyingFilter(
            "CIBlendWithAlphaMask",
            parameters: [kCIInputBackgroundImageKey: transparent, kCIInputMaskImageKey: mask]
        )
    }

    private static func addSparkles(to image: UIImage) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
            image.draw(at: .zero)
            let center = CGPoint(x: image.size.width / 2, y: image.size.height / 2)
            let radius = min(image.size.width, image.size.height) * 0.43
            for index in 0..<10 {
                let angle = CGFloat(index) / 10 * .pi * 2
                let point = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
                drawSparkle(at: point, size: index.isMultiple(of: 2) ? 18 : 11)
            }
        }
    }

    private static func drawSparkle(at point: CGPoint, size: CGFloat) {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: point.x, y: point.y - size))
        path.addLine(to: CGPoint(x: point.x + size * 0.22, y: point.y - size * 0.22))
        path.addLine(to: CGPoint(x: point.x + size, y: point.y))
        path.addLine(to: CGPoint(x: point.x + size * 0.22, y: point.y + size * 0.22))
        path.addLine(to: CGPoint(x: point.x, y: point.y + size))
        path.addLine(to: CGPoint(x: point.x - size * 0.22, y: point.y + size * 0.22))
        path.addLine(to: CGPoint(x: point.x - size, y: point.y))
        path.addLine(to: CGPoint(x: point.x - size * 0.22, y: point.y - size * 0.22))
        path.close()
        UIColor(white: 0.90, alpha: 1).setFill()
        path.fill()
    }
}

private extension CGFloat {
    var finiteOrZero: CGFloat { isFinite ? self : 0 }

    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
