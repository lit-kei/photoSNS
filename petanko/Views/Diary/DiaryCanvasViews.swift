import SwiftUI
import UIKit

enum DiaryCanvasMetrics {
    static let logicalSize = CGSize(width: 360, height: 480)
    static let stickerBaseSize: CGFloat = 118
    static let stickerScaleRange: ClosedRange<Double> = 0.55...3.4

    nonisolated static func sanitizedStickerLayout(_ layout: StickerLayout) -> StickerLayout {
        var result = layout
        let halfWidth = 180.0
        let halfHeight = 240.0
        let scaleRange = 0.55...3.4

        result.x = result.x.isFinite ? min(halfWidth, max(-halfWidth, result.x)) : 0
        result.y = result.y.isFinite ? min(halfHeight, max(-halfHeight, result.y)) : 0
        result.scale = result.scale.isFinite
            ? min(scaleRange.upperBound, max(scaleRange.lowerBound, result.scale))
            : 1
        result.rotation = result.rotation.isFinite ? result.rotation : 0
        return result
    }
}

extension UIColor {
    convenience init?(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard cleaned.count == 6, let value = Int(cleaned, radix: 16) else { return nil }
        self.init(
            red: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }

    var petankoHexString: String {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return String(
            format: "#%02X%02X%02X",
            Int(red * 255),
            Int(green * 255),
            Int(blue * 255)
        )
    }
}

struct DiaryCanvasView: View {
    let diary: DiaryPage
    let stickers: [StickerPost]
    @Binding var selectedSticker: StickerPost?

    var body: some View {
        ZStack {
            DiaryBackgroundView(
                background: diary.background,
                customImageURL: diary.backgroundImageURL
            )
                .zIndex(-2_000_000_000_000)

            ForEach(diary.designItems) { item in
                DiaryDesignVisual(item: item)
                    .scaleEffect(item.scale)
                    .rotationEffect(.degrees(item.rotation))
                    .position(x: item.x, y: item.y)
                    .allowsHitTesting(false)
                    .zIndex(950_000_000_000 + Double(item.zIndex))
            }

            ForEach(diary.textItems) { item in
                DiaryTextVisual(item: item)
                    .scaleEffect(item.scale)
                    .rotationEffect(.degrees(item.rotation))
                    .position(x: item.x, y: item.y)
                    .allowsHitTesting(false)
                    .zIndex(Double(item.zIndex))
            }

            ForEach(diary.stampItems) { item in
                DiaryStampVisual(item: item)
                    .scaleEffect(item.scale)
                    .rotationEffect(.degrees(item.rotation))
                    .position(x: item.x, y: item.y)
                    .allowsHitTesting(false)
                    .zIndex(Double(item.zIndex))
            }

            if shouldShowEmptyMessage {
                VStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.largeTitle)
                        .foregroundStyle(emptyMessageColor)
                    Text("ステッカーを貼るとここに集まります")
                        .font(.headline)
                        .foregroundStyle(emptyMessageColor)
                }
                .allowsHitTesting(false)
                .zIndex(-1_500_000_000_000)
            }

            ForEach(stickers) { sticker in
                let layout = diary.stickerLayout.first(where: { $0.stickerId == sticker.id }) ?? sticker.layout
                DiaryStickerVisual(
                    sticker: sticker,
                    size: DiaryCanvasMetrics.stickerBaseSize,
                    layout: layout,
                    designItems: diary.designItems
                )
                    .contentShape(Rectangle())
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onEnded { value in
                                guard isIntentionalStickerTap(value) else { return }
                                selectedSticker = sticker
                            }
                    )
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(sticker.authorName)のステッカー")
                    .accessibilityHint("ダブルタップすると詳細を表示します")
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction {
                        selectedSticker = sticker
                    }
                    .scaleEffect(layout.scale)
                    .rotationEffect(.degrees(layout.rotation))
                    .offset(x: layout.x, y: layout.y)
                    .zIndex(Double(layout.zIndex))
                    .transition(.scale.combined(with: .opacity))
            }

            DiaryDrawingLayer(strokes: diary.drawingStrokes)
                .allowsHitTesting(false)
                .zIndex(900_000_000_000)
        }
        .frame(width: DiaryCanvasMetrics.logicalSize.width, height: DiaryCanvasMetrics.logicalSize.height)
        .animation(.spring(response: 0.35, dampingFraction: 0.72), value: stickers.count)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .stroke(AppColors.border, lineWidth: 0.8)
        }
    }

    private var shouldShowEmptyMessage: Bool {
        stickers.isEmpty
            && diary.textItems.isEmpty
            && diary.stampItems.isEmpty
            && diary.designItems.isEmpty
            && diary.drawingStrokes.isEmpty
            && diary.backgroundImageURL?.isEmpty != false
    }

    private var emptyMessageColor: Color {
        diary.background == .stars ? .white : AppColors.mainText
    }

    private func isIntentionalStickerTap(_ value: DragGesture.Value) -> Bool {
        let movement = hypot(value.translation.width, value.translation.height)
        let predictedMovement = hypot(
            value.predictedEndLocation.x - value.startLocation.x,
            value.predictedEndLocation.y - value.startLocation.y
        )
        return movement <= 6 && predictedMovement <= 14
    }
}

struct DiaryDrawingLayer: View {
    let strokes: [DiaryDrawingStroke]

    var body: some View {
        Canvas { context, _ in
            for stroke in strokes {
                guard let first = stroke.points.first else { continue }
                let color = Color(
                    uiColor: UIColor(hex: stroke.colorHex) ?? UIColor(AppColors.mainText)
                )
                let lineWidth = max(1, min(CGFloat(stroke.lineWidth), 28))

                if stroke.points.count == 1 {
                    context.fill(
                        Path(
                            ellipseIn: CGRect(
                                x: CGFloat(first.x) - lineWidth / 2,
                                y: CGFloat(first.y) - lineWidth / 2,
                                width: lineWidth,
                                height: lineWidth
                            )
                        ),
                        with: .color(color)
                    )
                    continue
                }

                var path = Path()
                path.move(to: CGPoint(x: CGFloat(first.x), y: CGFloat(first.y)))
                for point in stroke.points.dropFirst() {
                    path.addLine(to: CGPoint(x: CGFloat(point.x), y: CGFloat(point.y)))
                }
                context.stroke(
                    path,
                    with: .color(color),
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
            }
        }
        .frame(width: DiaryCanvasMetrics.logicalSize.width, height: DiaryCanvasMetrics.logicalSize.height)
        .accessibilityHidden(true)
    }
}

struct DiaryDesignShapePath: Shape {
    let shape: DiaryDesignShape

    func path(in rect: CGRect) -> Path {
        switch shape {
        case .rectangle:
            return Rectangle().path(in: rect)
        case .circle:
            return Ellipse().path(in: rect)
        case .star:
            var path = Path()
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let outerX = rect.width / 2
            let outerY = rect.height / 2
            let innerRatio: CGFloat = 0.43
            for index in 0..<10 {
                let angle = -CGFloat.pi / 2 + CGFloat(index) * CGFloat.pi / 5
                let radius = index.isMultiple(of: 2) ? CGFloat(1) : innerRatio
                let point = CGPoint(
                    x: center.x + cos(angle) * outerX * radius,
                    y: center.y + sin(angle) * outerY * radius
                )
                if index == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }
            path.closeSubpath()
            return path
        case .heart:
            var path = Path()
            path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.addCurve(
                to: CGPoint(x: rect.minX, y: rect.height * 0.30 + rect.minY),
                control1: CGPoint(x: rect.width * 0.36 + rect.minX, y: rect.height * 0.76 + rect.minY),
                control2: CGPoint(x: rect.minX, y: rect.height * 0.56 + rect.minY)
            )
            path.addCurve(
                to: CGPoint(x: rect.midX, y: rect.height * 0.24 + rect.minY),
                control1: CGPoint(x: rect.minX, y: rect.minY),
                control2: CGPoint(x: rect.width * 0.36 + rect.minX, y: rect.minY)
            )
            path.addCurve(
                to: CGPoint(x: rect.maxX, y: rect.height * 0.30 + rect.minY),
                control1: CGPoint(x: rect.width * 0.64 + rect.minX, y: rect.minY),
                control2: CGPoint(x: rect.maxX, y: rect.minY)
            )
            path.addCurve(
                to: CGPoint(x: rect.midX, y: rect.maxY),
                control1: CGPoint(x: rect.maxX, y: rect.height * 0.56 + rect.minY),
                control2: CGPoint(x: rect.width * 0.64 + rect.minX, y: rect.height * 0.76 + rect.minY)
            )
            path.closeSubpath()
            return path
        }
    }
}

struct DiaryDesignVisual: View {
    let item: DiaryDesignItem
    var showsConfiguredBorder = true

    var body: some View {
        ZStack {
            effectContent

            if item.hasBorder && showsConfiguredBorder {
                DiaryDesignShapePath(shape: item.shape)
                    .stroke(borderColor, lineWidth: 1.15)
            }
        }
        .frame(width: item.width, height: item.height)
    }

    @ViewBuilder
    private var effectContent: some View {
        switch item.effect {
        case .invert:
            DiaryDesignShapePath(shape: item.shape)
                .fill(.white)
                .blendMode(.difference)
                .opacity(clampedOpacity)
        case .tint:
            DiaryDesignShapePath(shape: item.shape)
                .fill(.gray.opacity(clampedOpacity))
                .blendMode(.saturation)
        case .translucent:
            DiaryDesignShapePath(shape: item.shape)
                .fill(selectedColor.opacity(clampedOpacity))
        case .eightBit:
            eightBitOverlay
        }
    }

    private var eightBitOverlay: some View {
        Canvas { context, size in
            let blockSize: CGFloat = 9
            for row in 0...Int(ceil(size.height / blockSize)) {
                for column in 0...Int(ceil(size.width / blockSize)) {
                    let isDark = (row + column).isMultiple(of: 2)
                    let rect = CGRect(
                        x: CGFloat(column) * blockSize,
                        y: CGFloat(row) * blockSize,
                        width: blockSize,
                        height: blockSize
                    )
                    context.fill(
                        Path(rect),
                        with: .color(isDark ? .black.opacity(0.13) : .white.opacity(0.09))
                    )
                }
            }
        }
        .mask {
            DiaryDesignShapePath(shape: item.shape)
                .fill(.white)
        }
        .blendMode(.overlay)
        .opacity(clampedOpacity)
    }

    private var selectedColor: Color {
        Color(uiColor: UIColor(hex: item.colorHex) ?? UIColor.systemPink)
    }

    private var borderColor: Color {
        Color(uiColor: UIColor(hex: item.borderColorHex) ?? .white)
    }

    private var clampedOpacity: Double {
        min(1, max(0.08, item.opacity))
    }
}

struct DiaryStampVisual: View {
    let item: DiaryStampItem

    @ViewBuilder
    var body: some View {
        switch item.design {
        case .normal:
            stampText(color: selectedColor)
        case .sparkle:
            stampText(color: selectedColor)
                .overlay { sparkleHalo }
        case .layered:
            ZStack {
                stampText(color: AppColors.accentPink.opacity(0.88))
                    .offset(x: -3.5, y: -3)
                stampText(color: AppColors.accentBlue.opacity(0.92))
                    .offset(x: 3.5, y: 3)
                stampText(color: selectedColor)
            }
        case .neon:
            stampText(color: .white)
                .shadow(color: selectedColor.opacity(0.98), radius: 2)
                .shadow(color: selectedColor.opacity(0.90), radius: 6)
                .shadow(color: selectedColor.opacity(0.64), radius: 11)
        case .shadow:
            ZStack {
                stampText(color: .black.opacity(0.36))
                    .offset(x: 4, y: 5)
                stampText(color: selectedColor)
            }
        }
    }

    private func stampText(color: Color) -> some View {
        Text(item.symbol)
            .font(.largeTitle.bold())
            .foregroundStyle(color)
    }

    private var selectedColor: Color {
        Color(uiColor: UIColor(hex: item.colorHex) ?? UIColor(AppColors.mainText))
    }

    private var sparkleHalo: some View {
        ZStack {
            sparkle(size: 11, offset: CGSize(width: -23, height: -21))
            sparkle(size: 8, offset: CGSize(width: 23, height: -15))
            sparkle(size: 9, offset: CGSize(width: -21, height: 20))
            sparkle(size: 12, offset: CGSize(width: 22, height: 21))
        }
        .allowsHitTesting(false)
    }

    private func sparkle(size: CGFloat, offset: CGSize) -> some View {
        Image(systemName: "sparkle")
            .font(.system(size: size, weight: .bold))
            .foregroundStyle(AppColors.accentPink)
            .shadow(color: .white.opacity(0.9), radius: 1)
            .offset(offset)
    }
}

struct DiaryTextVisual: View {
    let item: DiaryTextItem

    var body: some View {
        ZStack {
            if !containsEmoji {
                ForEach(outlineOffsets.indices, id: \.self) { index in
                    styledText(color: resolvedOutlineColor)
                        .offset(outlineOffsets[index])
                }
            }

            styledText(color: resolvedColor)
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: 240)
    }

    private func styledText(color: Color) -> some View {
        Text(item.text)
            .font(resolvedFont)
            .foregroundStyle(color)
            .multilineTextAlignment(.center)
            .lineLimit(nil)
    }

    private var resolvedFont: Font {
        guard !item.fontName.isEmpty, UIFont(name: item.fontName, size: 24) != nil else {
            return .system(size: 24, weight: .bold)
        }
        return .custom(item.fontName, size: 24)
    }

    private var resolvedColor: Color {
        Color(uiColor: UIColor(hex: item.colorHex) ?? UIColor(AppColors.mainText))
    }

    private var resolvedOutlineColor: Color {
        let textColor = UIColor(hex: item.colorHex) ?? UIColor(AppColors.mainText)
        return textColor.petankoPerceivedBrightness > 0.68
            ? Color.black.opacity(0.58)
            : Color.white.opacity(0.92)
    }

    private var containsEmoji: Bool {
        item.text.unicodeScalars.contains { scalar in
            scalar.properties.isEmojiPresentation || scalar.value == 0xFE0F
        }
    }

    private var outlineOffsets: [CGSize] {
        let distance: CGFloat = 1.45
        return [
            CGSize(width: -distance, height: 0),
            CGSize(width: distance, height: 0),
            CGSize(width: 0, height: -distance),
            CGSize(width: 0, height: distance),
            CGSize(width: -distance, height: -distance),
            CGSize(width: distance, height: -distance),
            CGSize(width: -distance, height: distance),
            CGSize(width: distance, height: distance)
        ]
    }
}

private extension UIColor {
    var petankoPerceivedBrightness: CGFloat {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return red * 0.299 + green * 0.587 + blue * 0.114
    }
}

struct RemoteStickerView: View {
    let sticker: StickerPost
    let size: CGFloat
    var imageURLString: String? = nil

    var body: some View {
        AsyncStickerImage(
            urlString: imageURLString ?? sticker.stickerImageURL,
            fallbackSystemImage: "photo.fill"
        )
            .frame(width: size, height: size)
            .overlay {
                if sticker.decoration == .sparkle {
                    SparkleOverlay()
                        .frame(width: size * 1.12, height: size * 1.12)
                }
            }
    }
}

private struct PixelatedRemoteStickerView: View {
    let urlString: String
    let size: CGFloat

    @State private var pixelatedImage: UIImage?

    var body: some View {
        Group {
            if let pixelatedImage {
                Image(uiImage: pixelatedImage)
                    .resizable()
                    .interpolation(.none)
                    .aspectRatio(contentMode: .fit)
            } else {
                RemoteImageView(urlString: urlString, contentMode: .fit) {
                    Color.clear
                }
            }
        }
        .frame(width: size, height: size)
        .task(id: urlString) {
            await loadPixelatedImage()
        }
    }

    @MainActor
    private func loadPixelatedImage() async {
        guard let url = URL(string: urlString), !urlString.isEmpty else {
            pixelatedImage = nil
            return
        }

        do {
            let cachedImage = try await RemoteImageCache.shared.image(for: url)
            guard !Task.isCancelled else { return }
            pixelatedImage = Self.makeLowResolutionImage(from: cachedImage.image)
        } catch {
            guard !Task.isCancelled else { return }
            pixelatedImage = nil
        }
    }

    private static func makeLowResolutionImage(from image: UIImage) -> UIImage {
        let longestSide: CGFloat = 18
        let aspectRatio = max(image.size.width, 1) / max(image.size.height, 1)
        let pixelSize = aspectRatio >= 1
            ? CGSize(width: longestSide, height: max(1, longestSide / aspectRatio))
            : CGSize(width: max(1, longestSide * aspectRatio), height: longestSide)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: pixelSize, format: format).image { context in
            context.cgContext.interpolationQuality = .none
            image.draw(in: CGRect(origin: .zero, size: pixelSize))
        }
    }
}

struct DiaryStickerVisual: View {
    let sticker: StickerPost
    let size: CGFloat
    let layout: StickerLayout
    let designItems: [DiaryDesignItem]

    var body: some View {
        ZStack {
            Group {
                if activeGrayFilterItems.isEmpty {
                    RemoteStickerView(sticker: sticker, size: size)
                } else {
                    ZStack {
                        RemoteStickerView(sticker: sticker, size: size)

                        RemoteStickerView(sticker: sticker, size: size)
                            .grayscale(1)
                            .mask { grayFilterMask }
                    }
                    .compositingGroup()
                }
            }

            if !activeEightBitItems.isEmpty {
                PixelatedRemoteStickerView(
                    urlString: sticker.stickerImageURL,
                    size: size
                )
                .mask { eightBitMask }
            }
        }
        .frame(width: size, height: size)
    }

    private var activeGrayFilterItems: [DiaryDesignItem] {
        designItems.filter { item in
            item.effect == .tint
                && revealGeometry(for: item).intersectsSticker
        }
    }

    private var activeEightBitItems: [DiaryDesignItem] {
        designItems.filter { item in
            item.effect == .eightBit
                && revealGeometry(for: item).intersectsSticker
        }
    }

    private var grayFilterMask: some View {
        ZStack {
            ForEach(activeGrayFilterItems) { item in
                let geometry = revealGeometry(for: item)
                DiaryDesignShapePath(shape: item.shape)
                    .fill(.white.opacity(min(1, max(0.08, item.opacity))))
                    .frame(width: geometry.width, height: geometry.height)
                    .rotationEffect(.degrees(geometry.rotation))
                    .position(x: geometry.center.x, y: geometry.center.y)
            }
        }
        .frame(width: size, height: size)
    }

    private var eightBitMask: some View {
        ZStack {
            ForEach(activeEightBitItems) { item in
                let geometry = revealGeometry(for: item)
                DiaryDesignShapePath(shape: item.shape)
                    .fill(.white)
                    .frame(width: geometry.width, height: geometry.height)
                    .rotationEffect(.degrees(geometry.rotation))
                    .position(x: geometry.center.x, y: geometry.center.y)
            }
        }
        .frame(width: size, height: size)
    }

    private func revealGeometry(for item: DiaryDesignItem) -> ColorRevealGeometry {
        let stickerScale = max(abs(layout.scale), 0.01)
        let stickerRotation = layout.rotation * .pi / 180
        let stickerCenter = CGPoint(
            x: DiaryCanvasMetrics.logicalSize.width / 2 + layout.x,
            y: DiaryCanvasMetrics.logicalSize.height / 2 + layout.y
        )
        let deltaX = item.x - stickerCenter.x
        let deltaY = item.y - stickerCenter.y
        let cosine = cos(-stickerRotation)
        let sine = sin(-stickerRotation)
        let localX = ((deltaX * cosine) - (deltaY * sine)) / stickerScale
        let localY = ((deltaX * sine) + (deltaY * cosine)) / stickerScale
        let width = max(1, abs(item.width * item.scale) / stickerScale)
        let height = max(1, abs(item.height * item.scale) / stickerScale)
        let localRotation = item.rotation - layout.rotation
        let localRadians = localRotation * .pi / 180
        let boundingWidth = abs(width * cos(localRadians)) + abs(height * sin(localRadians))
        let boundingHeight = abs(width * sin(localRadians)) + abs(height * cos(localRadians))
        let center = CGPoint(x: size / 2 + localX, y: size / 2 + localY)
        let boundingRect = CGRect(
            x: center.x - boundingWidth / 2,
            y: center.y - boundingHeight / 2,
            width: boundingWidth,
            height: boundingHeight
        )

        return ColorRevealGeometry(
            center: center,
            width: width,
            height: height,
            rotation: localRotation,
            intersectsSticker: boundingRect.intersects(
                CGRect(x: 0, y: 0, width: size, height: size)
            )
        )
    }
}

private struct ColorRevealGeometry {
    let center: CGPoint
    let width: CGFloat
    let height: CGFloat
    let rotation: Double
    let intersectsSticker: Bool
}
