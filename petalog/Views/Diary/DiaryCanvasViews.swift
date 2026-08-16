import SwiftUI
import UIKit

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

    var petalogHexString: String {
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
            DiaryBackgroundView(background: diary.background)
                .zIndex(-2_000_000_000_000)

            ForEach(diary.textItems) { item in
                DiaryTextVisual(item: item)
                    .scaleEffect(item.scale)
                    .rotationEffect(.degrees(item.rotation))
                    .position(x: item.x, y: item.y)
                    .zIndex(Double(item.zIndex))
            }

            ForEach(diary.stampItems) { item in
                Text(item.symbol)
                    .font(.largeTitle.bold())
                    .foregroundStyle(Color(uiColor: UIColor(hex: item.colorHex) ?? UIColor(AppColors.mainText)))
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
                RemoteStickerView(sticker: sticker, size: 118)
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

struct DiaryTextVisual: View {
    let item: DiaryTextItem

    var body: some View {
        ZStack {
            ForEach(outlineOffsets.indices, id: \.self) { index in
                styledText(color: resolvedOutlineColor)
                    .offset(outlineOffsets[index])
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
        return textColor.petalogPerceivedBrightness > 0.68
            ? Color.black.opacity(0.58)
            : Color.white.opacity(0.92)
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
    var petalogPerceivedBrightness: CGFloat {
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
