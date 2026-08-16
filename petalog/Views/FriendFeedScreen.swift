import SwiftUI

struct FriendFeedScreen: View {
    @EnvironmentObject private var appState: AppState
    var showsRootTabBar = false

    var body: some View {
        ScrollView {
            FriendTodayFeedSection()
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)
        }
        .background {
            PetalogMetalBackground()
        }
        .rootTabBar(shows: showsRootTabBar, selection: $appState.selectedTab)
    }
}

struct FriendTodayFeedSection: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            header
            feedContent
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("今日のタイムライン")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(AppColors.mainText)
        }
    }

    @ViewBuilder
    private var feedContent: some View {
        if appState.friendTodayStickers.isEmpty {
            EmptyStateView(
                systemImage: "text.bubble",
                title: "今日のブログ投稿はまだありません",
                message: "自分や友達のブログ投稿がここに新しい順で表示されます。"
            )
        } else {
            LazyVStack(spacing: 16) {
                ForEach(appState.friendTodayStickers) { sticker in
                    FriendFeedCard(
                        sticker: sticker,
                        latestProfile: appState.observedUserProfiles[sticker.authorId]
                    )
                }
            }
        }
    }
}

private struct FriendFeedCard: View {
    let sticker: StickerPost
    let latestProfile: AppUser?

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
                    BlogAuthorAvatar(sticker: sticker, latestProfile: latestProfile)

                    Text(displayName)
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

    private var displayName: String {
        latestProfile?.displayName ?? sticker.authorName
    }
}

private struct BlogAuthorAvatar: View {
    let sticker: StickerPost
    let latestProfile: AppUser?

    var body: some View {
        Group {
            if let avatarURL = latestProfile?.avatarURL, !avatarURL.isEmpty {
                RemoteImageView(urlString: avatarURL) {
                    placeholder
                }
            } else if avatarText.isEmpty {
                placeholder
            } else {
                Text(avatarText)
                    .font(.system(size: 14))
            }
        }
        .frame(width: 28, height: 28)
        .background(AppColors.chromeHighlight.opacity(0.78))
        .clipShape(Circle())
        .overlay {
            Circle().stroke(AppColors.border, lineWidth: 0.7)
        }
    }

    private var avatarText: String {
        latestProfile?.avatar ?? sticker.authorAvatar
    }

    private var placeholder: some View {
        Image(systemName: "person.fill")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(AppColors.mainText.opacity(0.72))
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
