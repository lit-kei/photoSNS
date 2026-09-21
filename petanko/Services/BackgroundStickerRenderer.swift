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
        let source = foreground.petankoResized(maxDimension: 900)
        let filtered = try apply(effect, to: source)
        return try apply(decoration, to: filtered, outlineColor: outlineColor)
    }

    static func prepareForeground(
        _ foreground: UIImage,
        decoration: StickerDecoration,
        outlineColor: UIColor = .white
    ) throws -> UIImage {
        try prepareForeground(
            foreground,
            effect: .original,
            decoration: decoration,
            outlineColor: outlineColor
        )
    }

    static func renderImage(preparedForeground: UIImage, draft: StickerDraft) throws -> UIImage {
        let filters = draft.detailEdit.filters.sorted { $0.zIndex < $1.zIndex }
        let filteredForeground = try applyDetailFilters(
            filters,
            to: renderForegroundLayer(preparedForeground: preparedForeground, draft: draft)
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)
        return renderer.image { rendererContext in
            UIColor.clear.setFill()
            rendererContext.fill(CGRect(origin: .zero, size: canvasSize))

            for shape in draft.detailEdit.shapes.sorted(by: { $0.zIndex < $1.zIndex }) {
                if shape.isFilterEnabled {
                    let shapeLayer = renderShapeLayer(shape)
                    let filteredShape = (try? applyDetailFilters(filters, to: shapeLayer)) ?? shapeLayer
                    filteredShape.draw(in: CGRect(origin: .zero, size: canvasSize))
                } else {
                    drawShape(shape, in: rendererContext.cgContext)
                }
            }

            filteredForeground.draw(in: CGRect(origin: .zero, size: canvasSize))
        }
    }

    static func renderPNG(preparedForeground: UIImage, draft: StickerDraft) throws -> Data {
        let image = try renderImage(preparedForeground: preparedForeground, draft: draft)

        guard let data = image.pngData() else {
            throw PetankoError.message("ステッカー画像を書き出せませんでした。")
        }
        guard data.count <= 2_000_000 else {
            throw PetankoError.message("ステッカー画像が2MBを超えました。装飾を変更してもう一度お試しください。")
        }
        guard let cgImage = image.cgImage,
              cgImage.width == 512,
              cgImage.height == 512 else {
            throw PetankoError.message("ステッカー画像を512pxで作成できませんでした。")
        }
        return data
    }

    private static func renderFilterTargetLayer(preparedForeground: UIImage, draft: StickerDraft) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: canvasSize, format: format).image { rendererContext in
            UIColor.clear.setFill()
            rendererContext.fill(CGRect(origin: .zero, size: canvasSize))

            drawShapes(
                draft.detailEdit.shapes
                    .filter(\.isFilterEnabled)
                    .sorted { $0.zIndex < $1.zIndex },
                in: rendererContext.cgContext
            )
            drawForeground(preparedForeground, draft: draft, in: rendererContext.cgContext)
        }
    }

    private static func renderForegroundLayer(preparedForeground: UIImage, draft: StickerDraft) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: canvasSize, format: format).image { rendererContext in
            UIColor.clear.setFill()
            rendererContext.fill(CGRect(origin: .zero, size: canvasSize))
            drawForeground(preparedForeground, draft: draft, in: rendererContext.cgContext)
        }
    }

    private static func renderShapeLayer(_ shape: StickerDetailShapeItem) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: canvasSize, format: format).image { rendererContext in
            UIColor.clear.setFill()
            rendererContext.fill(CGRect(origin: .zero, size: canvasSize))
            drawShape(shape, in: rendererContext.cgContext)
        }
    }

    private static func drawForeground(_ image: UIImage, draft: StickerDraft, in cgContext: CGContext) {
        let rect = placementRect(
            imageSize: image.size,
            canvasSize: canvasSize,
            scale: draft.foregroundScale,
            offset: draft.foregroundOffset
        )
        cgContext.saveGState()
        cgContext.translateBy(x: rect.midX, y: rect.midY)
        cgContext.rotate(by: CGFloat(draft.foregroundRotation) * .pi / 180)
        image.draw(
            in: CGRect(x: -rect.width / 2, y: -rect.height / 2, width: rect.width, height: rect.height)
        )
        cgContext.restoreGState()
    }

    private static func drawShapes(_ shapes: [StickerDetailShapeItem], in cgContext: CGContext) {
        for shape in shapes {
            drawShape(shape, in: cgContext)
        }
    }

    private static func drawShape(_ shape: StickerDetailShapeItem, in cgContext: CGContext) {
        let width = CGFloat(shape.width * shape.scale)
        let height = CGFloat(shape.height * shape.scale)
        guard width > 0, height > 0 else { return }

        cgContext.saveGState()
        cgContext.translateBy(x: CGFloat(shape.x), y: CGFloat(shape.y))
        cgContext.rotate(by: CGFloat(shape.rotation) * .pi / 180)
        let rect = CGRect(x: -width / 2, y: -height / 2, width: width, height: height)
        let path = detailPath(kind: shape.type, in: rect)

        if let fillColor = detailColor(shape.fillColorHex) {
            fillColor.setFill()
            path.fill()
        }

        if shape.strokeWidth > 0,
           let strokeColor = detailColor(shape.strokeColorHex) {
            strokeColor.setStroke()
            path.lineWidth = CGFloat(shape.strokeWidth)
            path.stroke()
        }

        cgContext.restoreGState()
    }

    private static func applyDetailFilters(
        _ filters: [StickerDetailFilterItem],
        to image: UIImage
    ) throws -> UIImage {
        var result = image
        for filter in filters {
            result = try applyDetailFilter(filter, to: result)
        }
        return result
    }

    private static func applyDetailFilter(
        _ filter: StickerDetailFilterItem,
        to image: UIImage
    ) throws -> UIImage {
        let filtered: UIImage
        switch filter.type {
        case .invert:
            filtered = try filteredImage(image, filterName: "CIColorInvert")
        case .grayscale:
            filtered = try filteredImage(image, filterName: "CIPhotoEffectMono")
        case .translucentColor:
            return applyTranslucentColorFilter(filter, to: image)
        case .pixelate:
            filtered = try pixelatedImage(image, scale: filter.pixelScale)
        case .sepia:
            filtered = try sepiaImage(image)
        case .vivid:
            filtered = try vividImage(image)
        }

        return composite(filtered: filtered, over: image, in: filter)
    }

    private static func applyTranslucentColorFilter(
        _ filter: StickerDetailFilterItem,
        to image: UIImage
    ) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: canvasSize, format: format).image { rendererContext in
            image.draw(in: CGRect(origin: .zero, size: canvasSize))
            let cgContext = rendererContext.cgContext
            cgContext.saveGState()
            addClipPath(for: filter, in: cgContext)
            cgContext.setBlendMode(.sourceAtop)
            detailColor(filter.colorHex)?
                .withAlphaComponent(CGFloat(filter.opacity.clamped(to: 0...1)))
                .setFill()
            cgContext.fill(CGRect(origin: .zero, size: canvasSize))
            cgContext.restoreGState()
        }
    }

    private static func composite(
        filtered: UIImage,
        over image: UIImage,
        in filter: StickerDetailFilterItem
    ) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: canvasSize, format: format).image { rendererContext in
            image.draw(in: CGRect(origin: .zero, size: canvasSize))
            let cgContext = rendererContext.cgContext
            cgContext.saveGState()
            addClipPath(for: filter, in: cgContext)
            filtered.draw(in: CGRect(origin: .zero, size: canvasSize))
            cgContext.restoreGState()
        }
    }

    private static func addClipPath(for filter: StickerDetailFilterItem, in cgContext: CGContext) {
        let width = CGFloat(filter.width * filter.scale)
        let height = CGFloat(filter.height * filter.scale)
        guard width > 0, height > 0 else { return }

        let rect = CGRect(x: -width / 2, y: -height / 2, width: width, height: height)
        let path = detailPath(kind: filter.maskShape, in: rect)
        var transform = CGAffineTransform(translationX: CGFloat(filter.x), y: CGFloat(filter.y))
            .rotated(by: CGFloat(filter.rotation) * .pi / 180)
        if let transformedPath = path.cgPath.copy(using: &transform) {
            cgContext.addPath(transformedPath)
            cgContext.clip()
        }
    }

    private static func filteredImage(_ image: UIImage, filterName: String) throws -> UIImage {
        guard let cgImage = image.cgImage else { throw ForegroundExtractionError.invalidImage }
        let input = CIImage(cgImage: cgImage)
        let output = input.applyingFilter(filterName)
        guard let cgOutput = context.createCGImage(output.cropped(to: input.extent), from: input.extent) else {
            throw ForegroundExtractionError.renderingFailed
        }
        return UIImage(cgImage: cgOutput, scale: 1, orientation: .up)
    }

    private static func pixelatedImage(_ image: UIImage, scale: Double) throws -> UIImage {
        guard let cgImage = image.cgImage else { throw ForegroundExtractionError.invalidImage }
        let input = CIImage(cgImage: cgImage)
        let filter = CIFilter.pixellate()
        filter.inputImage = input
        filter.center = CGPoint(x: input.extent.midX, y: input.extent.midY)
        filter.scale = Float(scale.clamped(to: 4...32))
        guard let output = filter.outputImage,
              let cgOutput = context.createCGImage(output.cropped(to: input.extent), from: input.extent) else {
            throw ForegroundExtractionError.renderingFailed
        }
        return UIImage(cgImage: cgOutput, scale: 1, orientation: .up)
    }

    private static func sepiaImage(_ image: UIImage) throws -> UIImage {
        guard let cgImage = image.cgImage else { throw ForegroundExtractionError.invalidImage }
        let input = CIImage(cgImage: cgImage)
        let filter = CIFilter.sepiaTone()
        filter.inputImage = input
        filter.intensity = 0.86
        guard let output = filter.outputImage,
              let cgOutput = context.createCGImage(output.cropped(to: input.extent), from: input.extent) else {
            throw ForegroundExtractionError.renderingFailed
        }
        return UIImage(cgImage: cgOutput, scale: 1, orientation: .up)
    }

    private static func vividImage(_ image: UIImage) throws -> UIImage {
        guard let cgImage = image.cgImage else { throw ForegroundExtractionError.invalidImage }
        let input = CIImage(cgImage: cgImage)
        let filter = CIFilter.colorControls()
        filter.inputImage = input
        filter.saturation = 1.35
        filter.contrast = 1.10
        filter.brightness = 0.02
        guard let output = filter.outputImage,
              let cgOutput = context.createCGImage(output.cropped(to: input.extent), from: input.extent) else {
            throw ForegroundExtractionError.renderingFailed
        }
        return UIImage(cgImage: cgOutput, scale: 1, orientation: .up)
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
        case .whiteOutline:
            layers.append(coloredMask(dilate(mask, radius: 15), color: .white, extent: extent))
        case .sparkle:
            layers.append(coloredMask(dilate(mask, radius: 15), color: outlineColor, extent: extent))
        case .colorfulOutline:
            layers.append(coloredMask(dilate(mask, radius: 19), color: outlineColor, extent: extent))
            layers.append(coloredMask(dilate(mask, radius: 9), color: outlineColor.withAlphaComponent(0.55), extent: extent))
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
        let placements = randomSparklePlacements(in: image.size, count: 10)
        return UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
            image.draw(at: .zero)
            for placement in placements {
                drawSparkle(at: placement.point, size: placement.size)
            }
        }
    }

    private struct SparklePlacement {
        let point: CGPoint
        let size: CGFloat
    }

    private static func randomSparklePlacements(in imageSize: CGSize, count: Int) -> [SparklePlacement] {
        let availableSizes: [CGFloat] = [10, 12, 15, 18]
        let edgeInset = (availableSizes.max() ?? 18) + 5
        let safeRect = CGRect(origin: .zero, size: imageSize).insetBy(dx: edgeInset, dy: edgeInset)
        guard safeRect.width > 0, safeRect.height > 0 else { return [] }

        var placements: [SparklePlacement] = []
        for _ in 0..<count {
            let size = availableSizes.randomElement() ?? 12
            var placement: SparklePlacement?

            for _ in 0..<160 {
                let candidate = CGPoint(
                    x: CGFloat.random(in: safeRect.minX...safeRect.maxX),
                    y: CGFloat.random(in: safeRect.minY...safeRect.maxY)
                )
                let doesNotOverlap = placements.allSatisfy { existing in
                    let dx = candidate.x - existing.point.x
                    let dy = candidate.y - existing.point.y
                    let minimumDistance = size + existing.size + 7
                    return dx * dx + dy * dy >= minimumDistance * minimumDistance
                }
                if doesNotOverlap {
                    placement = SparklePlacement(point: candidate, size: size)
                    break
                }
            }

            if let placement {
                placements.append(placement)
            }
        }
        return placements
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

    private static func detailColor(_ hex: String) -> UIColor? {
        if hex == StickerDetailShapeItem.transparentColorHex {
            return nil
        }
        return UIColor(hex: hex) ?? .systemPink
    }

    private static func detailPath(kind: StickerDetailShapeKind, in rect: CGRect) -> UIBezierPath {
        switch kind {
        case .rectangle:
            return UIBezierPath(roundedRect: rect, cornerRadius: min(rect.width, rect.height) * 0.08)
        case .circle:
            return UIBezierPath(ovalIn: rect)
        case .star:
            return starPath(in: rect)
        case .heart:
            return heartPath(in: rect)
        }
    }

    private static func starPath(in rect: CGRect) -> UIBezierPath {
        let path = UIBezierPath()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerX = rect.width / 2
        let outerY = rect.height / 2
        let innerRatio: CGFloat = 0.44
        for index in 0..<10 {
            let angle = -CGFloat.pi / 2 + CGFloat(index) * CGFloat.pi / 5
            let radius = index.isMultiple(of: 2) ? CGFloat(1) : innerRatio
            let point = CGPoint(
                x: center.x + cos(angle) * outerX * radius,
                y: center.y + sin(angle) * outerY * radius
            )
            index == 0 ? path.move(to: point) : path.addLine(to: point)
        }
        path.close()
        return path
    }

    private static func heartPath(in rect: CGRect) -> UIBezierPath {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addCurve(
            to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.30),
            controlPoint1: CGPoint(x: rect.minX + rect.width * 0.36, y: rect.minY + rect.height * 0.76),
            controlPoint2: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.56)
        )
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.24),
            controlPoint1: CGPoint(x: rect.minX, y: rect.minY),
            controlPoint2: CGPoint(x: rect.minX + rect.width * 0.36, y: rect.minY)
        )
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.30),
            controlPoint1: CGPoint(x: rect.minX + rect.width * 0.64, y: rect.minY),
            controlPoint2: CGPoint(x: rect.maxX, y: rect.minY)
        )
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.maxY),
            controlPoint1: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.56),
            controlPoint2: CGPoint(x: rect.minX + rect.width * 0.64, y: rect.minY + rect.height * 0.76)
        )
        path.close()
        return path
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
