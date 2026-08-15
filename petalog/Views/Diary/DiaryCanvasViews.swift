import SwiftUI

struct DiaryCanvasView: View {
    let diary: DiaryPage
    let stickers: [StickerPost]
    @Binding var selectedSticker: StickerPost?

    var body: some View {
        ZStack {
            DiaryBackgroundView(background: diary.background)

            ForEach(diary.textItems) { item in
                Text(item.text)
                    .font(.title3.bold())
                    .foregroundStyle(AppColors.mainText)
                    .position(x: item.x, y: item.y)
            }

            ForEach(diary.stampItems) { item in
                Text(item.symbol)
                    .font(.largeTitle.bold())
                    .rotationEffect(.degrees(item.rotation))
                    .position(x: item.x, y: item.y)
            }

            if stickers.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.largeTitle)
                        .foregroundStyle(AppColors.mainText)
                    Text("ステッカーを貼るとここに集まります")
                        .font(.headline)
                        .foregroundStyle(AppColors.mainText)
                }
            }

            ForEach(stickers.sorted { $0.layout.zIndex < $1.layout.zIndex }) { sticker in
                Button {
                    selectedSticker = sticker
                } label: {
                    RemoteStickerView(sticker: sticker, size: 118)
                }
                .buttonStyle(.plain)
                .scaleEffect(sticker.layout.scale)
                .rotationEffect(.degrees(sticker.layout.rotation))
                .offset(x: sticker.layout.x, y: sticker.layout.y)
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
}

struct RemoteStickerView: View {
    let sticker: StickerPost
    let size: CGFloat

    var body: some View {
        AsyncStickerImage(urlString: sticker.stickerImageURL, fallbackSystemImage: "photo.fill")
            .frame(width: size, height: size)
            .shadow(color: sticker.decoration == .shadow ? .black.opacity(0.24) : .clear, radius: 12, y: 8)
            .overlay {
                if sticker.decoration == .sparkle {
                    SparkleOverlay()
                        .frame(width: size * 1.12, height: size * 1.12)
                }
            }
    }
}
