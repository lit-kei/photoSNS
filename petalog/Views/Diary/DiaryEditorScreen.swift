import SwiftUI

struct DiaryEditorScreen: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let group: PetalogGroup
    @StateObject private var viewModel: DiaryViewModel
    @State private var draftDiary: DiaryPage?
    @State private var selectedStickerId: String?
    @State private var localLayouts: [String: StickerLayout] = [:]
    @State private var lockMessage: String?
    @State private var isSaving = false

    init(group: PetalogGroup) {
        self.group = group
        _viewModel = StateObject(wrappedValue: DiaryViewModel(group: group))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                if let lockMessage {
                    EmptyStateView(systemImage: "lock.fill", title: "編集中のメンバーがいます", message: lockMessage)
                }

                if var draftDiary {
                    TextField("タイトル", text: Binding(
                        get: { draftDiary.title },
                        set: { self.draftDiary?.title = $0 }
                    ))
                    .font(.title3.weight(.bold))
                    .textFieldStyle(.plain)
                    .metalTextField()

                    EditableDiaryCanvas(diary: draftDiary, stickers: viewModel.stickers, layouts: $localLayouts, selectedStickerId: $selectedStickerId)
                        .frame(height: 480)

                    ControlSection(title: "背景") {
                        HorizontalOptionPicker(options: ScrapbookBackground.allCases, selection: Binding(
                            get: { self.draftDiary?.background ?? .notebook },
                            set: { self.draftDiary?.background = $0 }
                        ))
                    }

                    ControlSection(title: "スタンプ") {
                        HStack(spacing: 10) {
                            ForEach(["★", "♥", "!!", "→", "✦", "☺"], id: \.self) { stamp in
                                Button(stamp) {
                                    self.draftDiary?.stampItems.append(DiaryStampItem(symbol: stamp))
                                }
                                .font(.title3.bold())
                                .frame(width: 44, height: 44)
                                .background(AppColors.surface.opacity(0.94))
                                .clipShape(RoundedRectangle(cornerRadius: AppRadius.chip, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: AppRadius.chip, style: .continuous)
                                        .stroke(AppColors.border, lineWidth: 0.8)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button {
                        Task { await save(draftDiary) }
                    } label: {
                        isSaving ? AnyView(ProgressView()) : AnyView(Label("保存する", systemImage: "checkmark.circle.fill"))
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                    .disabled(isSaving || lockMessage != nil)
                } else {
                    ProgressView("絵日記を読み込み中")
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
        .navigationTitle("絵日記編集")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.start() }
        .onDisappear {
            viewModel.stop()
            if let user = appState.currentUser {
                Task { await viewModel.releaseEditLock(user: user) }
            }
        }
        .onChange(of: viewModel.diary) { _, diary in
            guard let diary else { return }
            draftDiary = draftDiary ?? diary
            seedLayouts(from: diary)
            Task { await lockIfPossible() }
        }
        .onChange(of: viewModel.stickers) { _, _ in
            if let diary = viewModel.diary {
                seedLayouts(from: diary)
            }
        }
    }

    private func seedLayouts(from diary: DiaryPage) {
        var next = localLayouts
        for sticker in viewModel.stickers where next[sticker.id] == nil {
            next[sticker.id] = diary.stickerLayout.first(where: { $0.stickerId == sticker.id }) ?? sticker.layout
        }
        localLayouts = next
    }

    private func lockIfPossible() async {
        guard lockMessage == nil, let user = appState.currentUser else { return }
        let acquired = await viewModel.acquireEditLock(user: user)
        if !acquired {
            lockMessage = "少し待ってからもう一度開いてください。"
        }
    }

    private func save(_ diary: DiaryPage) async {
        isSaving = true
        var page = diary
        page.stickerLayout = Array(localLayouts.values).sorted { $0.zIndex < $1.zIndex }
        await viewModel.saveDiary(page)
        isSaving = false
        dismiss()
    }
}

struct EditableDiaryCanvas: View {
    let diary: DiaryPage
    let stickers: [StickerPost]
    @Binding var layouts: [String: StickerLayout]
    @Binding var selectedStickerId: String?

    var body: some View {
        ZStack {
            DiaryBackgroundView(background: diary.background)

            ForEach(diary.stampItems) { item in
                Text(item.symbol)
                    .font(.largeTitle.bold())
                    .rotationEffect(.degrees(item.rotation))
                    .position(x: item.x, y: item.y)
            }

            ForEach(stickers) { sticker in
                let layout = layouts[sticker.id] ?? sticker.layout
                RemoteStickerView(sticker: sticker, size: 118)
                    .scaleEffect(layout.scale)
                    .rotationEffect(.degrees(layout.rotation))
                    .offset(x: layout.x, y: layout.y)
                    .overlay {
                        if selectedStickerId == sticker.id {
                            RoundedRectangle(cornerRadius: AppRadius.card).stroke(AppColors.mainText, lineWidth: 1.5)
                        }
                    }
                    .gesture(
                        DragGesture().onChanged { value in
                            update(sticker.id) { current in
                                current.x = value.translation.width
                                current.y = value.translation.height
                            }
                        }
                    )
                    .simultaneousGesture(
                        MagnificationGesture().onChanged { value in
                            update(sticker.id) { current in
                                current.scale = min(1.8, max(0.55, value))
                            }
                        }
                    )
                    .simultaneousGesture(
                        RotationGesture().onChanged { value in
                            update(sticker.id) { current in
                                current.rotation = value.degrees
                            }
                        }
                    )
                    .onTapGesture {
                        selectedStickerId = sticker.id
                        update(sticker.id) { current in
                            current.zIndex = Int(Date().timeIntervalSince1970)
                        }
                    }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .stroke(AppColors.border, lineWidth: 0.8)
        }
    }

    private func update(_ stickerId: String, mutate: (inout StickerLayout) -> Void) {
        var layout = layouts[stickerId] ?? StickerLayout(stickerId: stickerId)
        mutate(&layout)
        layouts[stickerId] = layout
    }
}
