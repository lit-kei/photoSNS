import SwiftUI
import UIKit

enum DiaryCanvasMetrics {
    static let logicalSize = CGSize(width: 360, height: 480)
    static let stickerBaseSize: CGFloat = 118
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

            ForEach(diary.textItems) { item in
                DiaryTextVisual(item: item)
                    .scaleEffect(item.scale)
                    .rotationEffect(.degrees(item.rotation))
                    .position(x: item.x, y: item.y)
                    .zIndex(Double(item.zIndex))
            }

            ForEach(diary.stampItems) { item in
                DiaryStampVisual(item: item)
                    .scaleEffect(item.scale)
                    .rotationEffect(.degrees(item.rotation))
                    .position(x: item.x, y: item.y)
                    .zIndex(Double(item.zIndex))
            }

            if stickers.isEmpty && diary.textItems.isEmpty && diary.stampItems.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.largeTitle)
                        .foregroundStyle(AppColors.mainText)
                    Text("ステッカーを貼るとここに集まります")
                        .font(.headline)
                        .foregroundStyle(AppColors.mainText)
                }
                .zIndex(-1_500_000_000_000)
            }

            ForEach(stickers) { sticker in
                let layout = diary.stickerLayout.first(where: { $0.stickerId == sticker.id }) ?? sticker.layout
                RemoteStickerView(sticker: sticker, size: DiaryCanvasMetrics.stickerBaseSize)
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
        }
        .frame(width: DiaryCanvasMetrics.logicalSize.width, height: DiaryCanvasMetrics.logicalSize.height)
        .animation(.spring(response: 0.35, dampingFraction: 0.72), value: stickers.count)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .stroke(AppColors.border, lineWidth: 0.8)
        }
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

    var body: some View {
        AsyncStickerImage(urlString: sticker.stickerImageURL, fallbackSystemImage: "photo.fill")
            .frame(width: size, height: size)
            .overlay {
                if sticker.decoration == .sparkle {
                    SparkleOverlay()
                        .frame(width: size * 1.12, height: size * 1.12)
                }
            }
    }
}
