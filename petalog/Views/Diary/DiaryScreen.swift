import SwiftUI
import UIKit

struct DiaryScreen: View {
    @Environment(\.dismiss) private var dismiss
    let group: PetalogGroup
    @StateObject private var viewModel: DiaryViewModel
    @State private var selectedSticker: StickerPost?
    @State private var selectedDate = Date()
    @State private var dragOffset: CGFloat = 0
    @State private var pageEntranceOffset: CGFloat = 0
    @State private var isPageTransitioning = false
    @State private var transitionID = UUID()

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
                    .disabled(viewModel.isLoading)
                    .onChange(of: selectedDate) { oldDate, newDate in
                        changeDate(to: newDate, relativeTo: oldDate)
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

                VStack(spacing: 18) {
                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 520, maxHeight: 520)
                        diaryEditButtonPlaceholder
                    } else if let diary = viewModel.diary {
                        DiaryCanvasView(diary: diary, stickers: viewModel.stickers, selectedSticker: $selectedSticker)
                            .frame(height: 520)
                            .id(viewModel.dateKey)
                            .offset(x: dragOffset + pageEntranceOffset)
                            .opacity(1.0 - min(Double(abs(dragOffset + pageEntranceOffset)) / 520.0, 0.24))

                        NavigationLink {
                            DiaryEditorScreen(group: group)
                        } label: {
                            Label("絵日記を編集", systemImage: "pencil.and.outline")
                        }
                        .buttonStyle(SecondaryActionButtonStyle())
                    } else {
                        EmptyStateView(systemImage: "doc.text.image.fill", title: "今日のページを準備中", message: "ステッカーを投稿すると、このキャンバスに集まります。")
                            .frame(maxWidth: .infinity, minHeight: 520, maxHeight: 520)
                        diaryEditButtonPlaceholder
                    }
                }
                .frame(height: 590, alignment: .top)

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
        .simultaneousGesture(dateSwipeGesture)
        .background {
            PetalogMetalBackground()
        }
        .navigationTitle("今日の絵日記")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Label("戻る", systemImage: "chevron.left")
                }
            }
        }
        .onAppear { viewModel.start() }
        .onDisappear {
            transitionID = UUID()
            viewModel.stop()
        }
        .onChange(of: viewModel.diary?.id) { _, diaryID in
            guard diaryID != nil else { return }
            animateIncomingPageIfNeeded()
        }
        .onChange(of: viewModel.isLoading) { _, isLoading in
            guard !isLoading, viewModel.diary == nil else { return }
            pageEntranceOffset = 0
            dragOffset = 0
            isPageTransitioning = false
        }
        .sheet(item: $selectedSticker) { sticker in
            StickerDetailSheet(sticker: sticker)
                .presentationDetents([.medium])
        }
    }

    private var diaryEditButtonPlaceholder: some View {
        Color.clear
            .frame(height: 52)
            .accessibilityHidden(true)
    }

    private var pageTravelDistance: CGFloat {
        max(UIScreen.main.bounds.width, 320) + 40
    }

    private func animateIncomingPageIfNeeded() {
        guard pageEntranceOffset != 0 else {
            isPageTransitioning = false
            return
        }
        Task { @MainActor in
            await Task.yield()
            withAnimation(.easeOut(duration: 0.24)) {
                pageEntranceOffset = 0
            }
            try? await Task.sleep(for: .seconds(0.24))
            isPageTransitioning = false
        }
    }

    private var dateSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 24)
            .onChanged { value in
                guard !viewModel.isLoading, !isPageTransitioning else { return }
                guard abs(value.translation.width) > abs(value.translation.height) else {
                    dragOffset = 0
                    return
                }
                dragOffset = min(max(value.translation.width, -pageTravelDistance), pageTravelDistance)
            }
            .onEnded { value in
                guard !viewModel.isLoading, !isPageTransitioning else { return }
                guard abs(value.translation.width) > abs(value.translation.height) else {
                    dragOffset = 0
                    return
                }
                let threshold: CGFloat = 72
                if value.translation.width < -threshold {
                    requestDateChange(to: selectedDate.addingTimeInterval(24 * 60 * 60))
                } else if value.translation.width > threshold {
                    requestDateChange(to: selectedDate.addingTimeInterval(-24 * 60 * 60))
                } else {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        dragOffset = 0
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }
    }

    private func changeDate(to date: Date, relativeTo referenceDate: Date? = nil) {
        requestDateChange(to: date, relativeTo: referenceDate)
    }

    private func requestDateChange(to date: Date, relativeTo referenceDate: Date? = nil) {
        guard !viewModel.isLoading, !isPageTransitioning else { return }
        let clampedDate = min(date, Date())
        let nextDateKey = clampedDate.petalogDateKey
        guard nextDateKey != viewModel.dateKey else {
            selectedDate = clampedDate
            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                dragOffset = 0
            }
            return
        }

        let calendar = Calendar.current
        let previousDay = calendar.startOfDay(for: referenceDate ?? selectedDate)
        let nextDay = calendar.startOfDay(for: clampedDate)
        let outgoingOffset = nextDay > previousDay ? -pageTravelDistance : pageTravelDistance
        let incomingOffset = -outgoingOffset
        let currentTransitionID = UUID()
        transitionID = currentTransitionID
        isPageTransitioning = true

        withAnimation(.easeOut(duration: 0.16)) {
            dragOffset = outgoingOffset
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.16))
            guard transitionID == currentTransitionID else { return }
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                pageEntranceOffset = incomingOffset
                dragOffset = 0
                selectedDate = clampedDate
                viewModel.changeDate(to: nextDateKey)
            }
        }
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
