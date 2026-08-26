import SwiftUI
import UIKit

struct DiaryScreen: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let group: PetalogGroup
    @StateObject private var viewModel: DiaryViewModel
    @State private var selectedSticker: StickerPost?
    @State private var selectedDate = Date()
    @State private var dragOffset: CGFloat = 0
    @State private var pageEntranceOffset: CGFloat = 0
    @State private var isPageTransitioning = false
    @State private var transitionID = UUID()
    @State private var isShowingPastEditExplanation = false

    init(group: PetalogGroup) {
        self.group = group
        _viewModel = StateObject(wrappedValue: DiaryViewModel(group: group))
    }

    var body: some View {
        VStack(spacing: 10) {
            VStack(spacing: 0) {
                HStack {
                    Text(selectedDate.petalogDisplayDate)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppColors.secondaryText)
                    Spacer()
                }
                diaryPageViewport
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                diaryEditArea
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            DateNavigator(
                selectedDate: $selectedDate,
                earliestDate: earliestDiaryDate,
                canMoveBackward: canMoveBackward,
                canMoveForward: !Calendar.current.isDateInToday(selectedDate),
                movePrevious: { changeDate(to: selectedDate.addingTimeInterval(-24 * 60 * 60)) },
                moveNext: { changeDate(to: selectedDate.addingTimeInterval(24 * 60 * 60)) },
                moveToday: { changeDate(to: Date()) }
            )
            .disabled(viewModel.isLoading)
            .onChange(of: selectedDate) { oldDate, newDate in
                changeDate(to: newDate, relativeTo: oldDate)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .simultaneousGesture(dateSwipeGesture)
        .background {
            PetalogMetalBackground()
        }
        .navigationTitle(group.name)
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
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    GroupEditScreen(group: group)
                } label: {
                    Image(systemName: "person.3")
                }
                .accessibilityLabel("グループを編集")
            }
        }
        .onAppear {
            appState.markGroupAsRead(group.id)
            viewModel.start()
        }
        .onDisappear {
            appState.markGroupAsRead(group.id)
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
        .alert("過去の絵日記は編集できません", isPresented: $isShowingPastEditExplanation) {
            Button("今日へ移動") {
                changeDate(to: Date())
            }
            Button("閉じる", role: .cancel) {}
        } message: {
            Text("絵日記の編集は当日のみできます。今日の絵日記に移動して編集してください。")
        }
    }

    @ViewBuilder
    private var diaryPageViewport: some View {
        if viewModel.isLoading {
            DiaryPageViewport {
                ProgressView()
            }
        } else if let diary = viewModel.diary {
            DiaryPageViewport {
                DiaryCanvasView(diary: diary, stickers: viewModel.stickers, selectedSticker: $selectedSticker)
            }
            .id(viewModel.dateKey)
            .offset(x: dragOffset + pageEntranceOffset)
            .opacity(1.0 - min(Double(abs(dragOffset + pageEntranceOffset)) / 520.0, 0.24))
        } else {
            DiaryPageViewport {
                EmptyStateView(
                    systemImage: "doc.text.image.fill",
                    title: "今日のページを準備中",
                    message: "ステッカーを投稿すると、このキャンバスに集まります。"
                )
            }
        }
    }

    @ViewBuilder
    private var diaryEditArea: some View {
        if viewModel.isLoading {
            diaryEditButtonPlaceholder
        } else if viewModel.diary != nil {
            diaryEditControl
        } else if canEditSelectedDiary {
            diaryEditButtonPlaceholder
        } else {
            pastDiaryEditButton
        }
    }

    @ViewBuilder
    private var diaryEditControl: some View {
        if canEditSelectedDiary {
            NavigationLink {
                DiaryEditorScreen(group: group)
            } label: {
                Label("絵日記を編集", systemImage: "pencil.and.outline")
            }
            .buttonStyle(PrimaryActionButtonStyle())
        } else {
            pastDiaryEditButton
        }
    }

    private var pastDiaryEditButton: some View {
        Button {
            changeDate(to: Date())
        } label: {
            Label("今日の絵日記へ", systemImage: "calendar.badge.clock")
        }
        .buttonStyle(SecondaryActionButtonStyle(backgroundColor: AppColors.accentBlue))
        .accessibilityLabel("今日の絵日記へ移動します")
    }

    private var diaryEditButtonPlaceholder: some View {
        Color.clear
            .frame(height: 52)
            .accessibilityHidden(true)
    }

    private var canEditSelectedDiary: Bool {
        Calendar.current.isDateInToday(selectedDate)
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
                } else if value.translation.width > threshold, canMoveBackward {
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
        let clampedDate = clampedDiaryDate(date)
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

    private var earliestDiaryDate: Date {
        Calendar.current.startOfDay(for: group.createdAt)
    }

    private var canMoveBackward: Bool {
        Calendar.current.startOfDay(for: selectedDate) > earliestDiaryDate
    }

    private func clampedDiaryDate(_ date: Date) -> Date {
        min(max(date, earliestDiaryDate), Date())
    }
}

private struct DiaryPageViewport<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        GeometryReader { proxy in
            let logicalSize = DiaryCanvasMetrics.logicalSize
            let scale = min(
                max(proxy.size.width, 1) / logicalSize.width,
                max(proxy.size.height, 1) / logicalSize.height
            )

            content
                .frame(width: logicalSize.width, height: logicalSize.height)
                .scaleEffect(scale)
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
    }
}

private struct DateNavigator: View {
    @Binding var selectedDate: Date
    let earliestDate: Date
    let canMoveBackward: Bool
    let canMoveForward: Bool
    let movePrevious: () -> Void
    let moveNext: () -> Void
    let moveToday: () -> Void

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
                    .foregroundStyle(canMoveBackward ? AppColors.mainText : AppColors.secondaryText.opacity(0.45))
                    .background(AppColors.chromeHighlight.opacity(canMoveBackward ? 0.78 : 0.42))
                    .clipShape(Circle())
                    .overlay { Circle().stroke(AppColors.border, lineWidth: 0.8) }
                    .disabled(!canMoveBackward)

                    DatePicker(
                        "絵日記の日付",
                        selection: $selectedDate,
                        in: earliestDate...Date(),
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
/*
                Group {
                    if canMoveForward {
                        Button(action: moveToday) {
                            Label("今日の絵日記へ", systemImage: "calendar.badge.clock")
                                .font(.system(size: 12, weight: .semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(AppColors.accentBlue.opacity(0.72), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(AppColors.mainText)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 30)*/
            }
        }

    }
}

private struct StickerDetailSheet: View {
    @EnvironmentObject private var appState: AppState
    let sticker: StickerPost
    @State private var photoSaveMessage: String?
    @State private var isSavingToPhotos = false

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

            if sticker.authorId == appState.currentUser?.id {
                Button {
                    saveStickerToPhotos()
                } label: {
                    Label(isSavingToPhotos ? "保存中…" : "写真に保存", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .disabled(isSavingToPhotos || sticker.stickerImageURL.isEmpty)
            }
        }
        .padding(24)
        .alert("写真への保存", isPresented: Binding(
            get: { photoSaveMessage != nil },
            set: { if !$0 { photoSaveMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(photoSaveMessage ?? "")
        }
    }

    private func saveStickerToPhotos() {
        guard !isSavingToPhotos else { return }
        isSavingToPhotos = true
        Task {
            do {
                try await StickerPhotoLibraryService.saveSticker(from: sticker.stickerImageURL)
                photoSaveMessage = "ステッカーを写真に保存しました。"
            } catch {
                photoSaveMessage = error.localizedDescription
            }
            isSavingToPhotos = false
        }
    }
}
