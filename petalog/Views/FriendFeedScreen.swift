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
                .font(.system(size: 25, weight: .bold))
                .foregroundStyle(AppColors.mainText)
        }
    }

    @ViewBuilder
    private var feedContent: some View {
        if appState.friendTodayStickers.isEmpty {
            EmptyStateView(
                systemImage: "text.bubble",
                title: "今日のブログ投稿はまだありません",
                message: nil
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
    @EnvironmentObject private var appState: AppState
    let sticker: StickerPost
    let latestProfile: AppUser?
    @State private var isShowingActions = false
    @State private var isConfirmingReport = false
    @State private var photoSaveMessage: String?
    @State private var reportMessage: String?
    @State private var isSavingToPhotos = false
    @State private var isReporting = false
    @State private var didReport = false

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

                    Button {
                        isShowingActions = true
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppColors.secondaryText)
                            .frame(width: 30, height: 30)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("投稿メニュー")
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
        .sheet(isPresented: $isShowingActions) {
            FriendFeedActionSheet(
                isSavingToPhotos: isSavingToPhotos,
                isReporting: isReporting,
                didReport: didReport,
                canReport: sticker.authorId != appState.currentUser?.id,
                saveAction: {
                    saveStickerToPhotos()
                },
                reportAction: {
                    isShowingActions = false
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(0.2))
                        isConfirmingReport = true
                    }
                }
            )
            .presentationDetents([.height(sticker.authorId == appState.currentUser?.id ? 126 : 190)])
            .presentationDragIndicator(.visible)
        }
        .confirmationDialog("画像を報告しますか？", isPresented: $isConfirmingReport, titleVisibility: .visible) {
            Button("不適切な画像として報告", role: .destructive) {
                reportSticker()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("報告内容は確認のために保存されます。投稿は自動で削除されません。")
        }
        .alert("写真への保存", isPresented: Binding(
            get: { photoSaveMessage != nil },
            set: { if !$0 { photoSaveMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(photoSaveMessage ?? "")
        }
        .alert("報告", isPresented: Binding(
            get: { reportMessage != nil },
            set: { if !$0 { reportMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(reportMessage ?? "")
        }
    }

    private var displayName: String {
        latestProfile?.displayName ?? sticker.authorName
    }

    private func saveStickerToPhotos() {
        guard !isSavingToPhotos else { return }
        isSavingToPhotos = true
        Task {
            do {
                try await StickerPhotoLibraryService.saveSticker(from: sticker.stickerImageURL)
                photoSaveMessage = "写真を保存しました。"
            } catch {
                photoSaveMessage = error.localizedDescription
            }
            isSavingToPhotos = false
            isShowingActions = false
        }
    }

    private func reportSticker() {
        guard !isReporting, !didReport else { return }
        isReporting = true
        Task {
            let success = await appState.reportSticker(sticker)
            didReport = success
            reportMessage = success ? "報告しました。" : "報告できませんでした。"
            isReporting = false
        }
    }
}

private struct FriendFeedActionSheet: View {
    let isSavingToPhotos: Bool
    let isReporting: Bool
    let didReport: Bool
    let canReport: Bool
    let saveAction: () -> Void
    let reportAction: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Button(action: saveAction) {
                Label(isSavingToPhotos ? "保存中…" : "写真を保存", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .disabled(isSavingToPhotos)

            if canReport {
                Button(role: .destructive, action: reportAction) {
                    Label(isReporting ? "報告中…" : didReport ? "報告済み" : "報告する", systemImage: "exclamationmark.bubble")
                }
                .buttonStyle(SecondaryActionButtonStyle(foregroundColor: AppColors.destructiveRed))
                .disabled(isReporting || didReport)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 22)
        .background {
            PetalogMetalBackground()
                .ignoresSafeArea()
        }
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
