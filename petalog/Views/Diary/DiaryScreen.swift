import SwiftUI

struct DiaryScreen: View {
    let group: PetalogGroup
    @StateObject private var viewModel: DiaryViewModel
    @State private var selectedSticker: StickerPost?

    init(group: PetalogGroup) {
        self.group = group
        _viewModel = StateObject(wrappedValue: DiaryViewModel(group: group))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(Date().petalogDisplayDate)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppColors.secondaryText)
                    Text(group.name)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(AppColors.mainText)
                    MemberAvatarStack(avatars: group.memberAvatars)
                }

                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 420)
                } else if let diary = viewModel.diary {
                    DiaryCanvasView(diary: diary, stickers: viewModel.stickers, selectedSticker: $selectedSticker)
                        .frame(height: 520)

                    NavigationLink {
                        DiaryEditorScreen(group: group)
                    } label: {
                        Label("絵日記を編集", systemImage: "pencil.and.outline")
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                } else {
                    EmptyStateView(systemImage: "doc.text.image.fill", title: "今日のページを準備中", message: "ステッカーを投稿すると、このキャンバスに集まります。")
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, AppSpacing.floatingTabClearance)
        }
        .background {
            PetalogMetalBackground()
        }
        .navigationTitle("今日の絵日記")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.start() }
        .onDisappear { viewModel.stop() }
        .sheet(item: $selectedSticker) { sticker in
            StickerDetailSheet(sticker: sticker)
                .presentationDetents([.medium])
        }
    }
}

private struct StickerDetailSheet: View {
    let sticker: StickerPost

    var body: some View {
        VStack(spacing: 18) {
            RemoteStickerView(sticker: sticker, size: 180)

            VStack(alignment: .leading, spacing: 8) {
                Label(sticker.authorName, systemImage: "person.crop.circle.fill")
                Label(sticker.comment.isEmpty ? "コメントなし" : sticker.comment, systemImage: "bubble.left.fill")
                if let url = URL(string: sticker.originalPhotoURL) {
                    Link(destination: url) {
                        Label("元の写真を開く", systemImage: "photo.fill")
                    }
                }
            }
            .font(.headline)
            .foregroundStyle(AppColors.mainText)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(24)
    }
}
