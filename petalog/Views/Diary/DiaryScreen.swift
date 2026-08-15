import SwiftUI
import UIKit

struct DiaryScreen: View {
    let group: PetalogGroup
    @StateObject private var viewModel: DiaryViewModel
    @State private var selectedSticker: StickerPost?
    @State private var selectedDate = Date()
    @State private var dragOffset: CGFloat = 0

    init(group: PetalogGroup) {
        self.group = group
        _viewModel = StateObject(wrappedValue: DiaryViewModel(group: group))
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    DateNavigator(
                        selectedDate: $selectedDate,
                        canMoveForward: !Calendar.current.isDateInToday(selectedDate),
                        movePrevious: { changeDate(to: selectedDate.addingTimeInterval(-24 * 60 * 60)) },
                        moveNext: { changeDate(to: selectedDate.addingTimeInterval(24 * 60 * 60)) }
                    )
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
                        .id(viewModel.dateKey)
                        .offset(x: dragOffset)
                        .opacity(1.0 - min(Double(abs(dragOffset)) / 360.0, 0.18))
                        .animation(.spring(response: 0.28, dampingFraction: 0.88), value: dragOffset)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))

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
        .simultaneousGesture(
            DragGesture(minimumDistance: 44)
                .onChanged { value in
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    dragOffset = value.translation.width * 0.22
                }
                .onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    let threshold: CGFloat = 72
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        dragOffset = 0
                    }
                    if value.translation.width < -threshold {
                        changeDate(to: selectedDate.addingTimeInterval(24 * 60 * 60))
                    } else if value.translation.width > threshold {
                        changeDate(to: selectedDate.addingTimeInterval(-24 * 60 * 60))
                    } else {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
        withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) {
            selectedDate = clampedDate
        }
        guard nextDateKey != viewModel.dateKey else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        viewModel.changeDate(to: nextDateKey)
    }
}

private struct DateNavigator: View {
    @Binding var selectedDate: Date
    let canMoveForward: Bool
    let movePrevious: () -> Void
    let moveNext: () -> Void

    var body: some View {
        MetalCard(padding: 12) {
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    Button(action: movePrevious) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(width: 38, height: 38)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(AppColors.mainText)
                    .background(AppColors.chromeHighlight.opacity(0.78))
                    .clipShape(Circle())
                    .overlay { Circle().stroke(AppColors.border, lineWidth: 0.8) }

                    DatePicker(
                        "絵日記の日付",
                        selection: $selectedDate,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .tint(AppColors.mainText)
                    .frame(maxWidth: .infinity)

                    Button(action: moveNext) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(width: 38, height: 38)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(canMoveForward ? AppColors.mainText : AppColors.secondaryText.opacity(0.45))
                    .background(AppColors.chromeHighlight.opacity(canMoveForward ? 0.78 : 0.42))
                    .clipShape(Circle())
                    .overlay { Circle().stroke(AppColors.border, lineWidth: 0.8) }
                    .disabled(!canMoveForward)
                }

                HStack(spacing: 8) {
                    Image(systemName: "arrow.left.and.right")
                        .font(.system(size: 11, weight: .semibold))
                    Text("左右にスワイプして日付を移動")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(AppColors.secondaryText)
                .frame(maxWidth: .infinity)
            }
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
            }
            .font(.headline)
            .foregroundStyle(AppColors.mainText)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(24)
    }
}
