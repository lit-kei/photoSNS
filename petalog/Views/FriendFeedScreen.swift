import SwiftUI

struct FriendFeedScreen: View {
    @EnvironmentObject private var appState: AppState
    var showsRootTabBar = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                feedContent
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)
        }
        .background {
            PetalogMetalBackground()
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if showsRootTabBar {
                AttachedBottomTabBar(selection: $appState.selectedTab)
                    .ignoresSafeArea(.keyboard, edges: .bottom)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("今日の友達")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(AppColors.mainText)
            Text("友達が今日撮った写真だけをまとめて見られます。")
                .font(.system(size: 14))
                .foregroundStyle(AppColors.secondaryText)
                .lineSpacing(3)
        }
    }

    @ViewBuilder
    private var feedContent: some View {
        if appState.friends.isEmpty {
            EmptyStateView(
                systemImage: "person.2",
                title: "まだ友達がいません",
                message: "友達ができると、ここに今日の投稿が表示されます。"
            )
        } else if appState.friendTodayStickers.isEmpty {
            EmptyStateView(
                systemImage: "photo.on.rectangle",
                title: "今日の投稿はまだありません",
                message: "友達が写真を撮ると、ここに新しい順で表示されます。"
            )
        } else {
            LazyVStack(spacing: 16) {
                ForEach(appState.friendTodayStickers) { sticker in
                    FriendFeedCard(sticker: sticker)
                }
            }
        }
    }
}

private struct FriendFeedCard: View {
    let sticker: StickerPost

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            RemoteImageView(urlString: sticker.stickerImageURL) {
                ZStack {
                    AppColors.accentBlue.opacity(0.34)
                    Image(systemName: "photo")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(AppColors.mainText.opacity(0.58))
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(sticker.authorName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppColors.mainText)
                    Spacer()
                    Text(sticker.createdAt.petalogTimeText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppColors.secondaryText)
                }

                if !sticker.comment.isEmpty {
                    Text(sticker.comment)
                        .font(.system(size: 14))
                        .foregroundStyle(AppColors.secondaryText)
                        .lineLimit(3)
                        .lineSpacing(3)
                }
            }
        }
        .padding(12)
        .background(AppColors.surface.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .stroke(AppColors.border, lineWidth: 0.8)
        }
    }
}

private extension Date {
    var petalogTimeText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "H:mm"
        return formatter.string(from: self)
    }
}
