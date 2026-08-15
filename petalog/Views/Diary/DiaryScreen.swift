import SwiftUI

struct DiaryScreen: View {
    let group: PetalogGroup
    @StateObject private var viewModel: DiaryViewModel
    @State private var selectedSticker: StickerPost?
    @State private var selectedDate = Date()

    init(group: PetalogGroup) {
        self.group = group
        _viewModel = StateObject(wrappedValue: DiaryViewModel(group: group))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    DatePicker(
                        "絵日記の日付",
                        selection: $selectedDate,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .tint(AppColors.mainText)
                    .onChange(of: selectedDate) { _, date in
                        changeDate(to: date)
                    }

                    Text(selectedDate.petalogDisplayDate)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppColors.secondaryText)
                    HStack(alignment: .center, spacing: 12) {
                        GroupIconView(icon: group.icon, iconURL: group.iconURL, imageData: nil, size: 50, fontSize: 24)
                        Text(group.name)
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(AppColors.mainText)
                            .lineLimit(2)
                    }
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

                NavigationLink {
                    GroupEditScreen(group: group)
                } label: {
                    Label("グループを編集", systemImage: "person.3.sequence")
                }
                .buttonStyle(SecondaryActionButtonStyle())

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
        .gesture(
            DragGesture(minimumDistance: 44)
                .onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    if value.translation.width < -44 {
                        changeDate(to: selectedDate.addingTimeInterval(24 * 60 * 60))
                    } else if value.translation.width > 44 {
                        changeDate(to: selectedDate.addingTimeInterval(-24 * 60 * 60))
                    }
                }
        )
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

    private func changeDate(to date: Date) {
        let clampedDate = min(date, Date())
        let nextDateKey = clampedDate.petalogDateKey
        selectedDate = clampedDate
        guard nextDateKey != viewModel.dateKey else { return }
        viewModel.changeDate(to: nextDateKey)
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
