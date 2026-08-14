//
//  DiaryScreens.swift
//  petalog
//

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
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PetalogTheme.secondaryText)
                    Text(group.name)
                        .font(.largeTitle.bold())
                        .foregroundStyle(PetalogTheme.text)
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
            .padding(20)
        }
        .background(PetalogTheme.background)
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
                    .foregroundStyle(PetalogTheme.text)
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
                        .foregroundStyle(PetalogTheme.primary)
                    Text("ステッカーを貼るとここに集まります")
                        .font(.headline)
                        .foregroundStyle(PetalogTheme.text)
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
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(PetalogTheme.border, lineWidth: 1)
        }
    }
}

private struct RemoteStickerView: View {
    let sticker: StickerPost
    let size: CGFloat

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            AsyncStickerImage(urlString: sticker.stickerImageURL, fallbackSystemImage: "photo.fill")
                .frame(width: size, height: size)
                .shadow(color: sticker.decoration == .shadow ? .black.opacity(0.24) : .clear, radius: 12, y: 8)
                .overlay {
                    if sticker.decoration == .sparkle {
                        SparkleOverlay()
                            .frame(width: size * 1.12, height: size * 1.12)
                    }
                }

            Text(sticker.authorAvatar)
                .font(.system(size: size * 0.22))
                .frame(width: size * 0.31, height: size * 0.31)
                .background(.white)
                .clipShape(Circle())
                .overlay { Circle().stroke(.white, lineWidth: 2) }
        }
        .frame(width: size * 1.22, height: size * 1.22)
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
            .foregroundStyle(PetalogTheme.text)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(24)
    }
}

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
                    .textFieldStyle(.roundedBorder)

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
                                .background(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(PetalogTheme.border, lineWidth: 1)
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
            .padding(20)
        }
        .background(PetalogTheme.background)
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

private struct EditableDiaryCanvas: View {
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
                            RoundedRectangle(cornerRadius: 8).stroke(PetalogTheme.primary, lineWidth: 2)
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
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(PetalogTheme.border, lineWidth: 1)
        }
    }

    private func update(_ stickerId: String, mutate: (inout StickerLayout) -> Void) {
        var layout = layouts[stickerId] ?? StickerLayout(stickerId: stickerId)
        mutate(&layout)
        layouts[stickerId] = layout
    }
}

struct GroupManagementScreen: View {
    enum Mode {
        case list
        case create
        case join
    }

    @EnvironmentObject private var appState: AppState
    let initialMode: Mode
    @State private var groupName = ""
    @State private var groupIcon = "📘"
    @State private var inviteCode = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if initialMode != .join {
                    ControlSection(title: "所属グループ") {
                        if appState.groups.isEmpty {
                            EmptyStateView(systemImage: "person.3.fill", title: "グループなし", message: "作成すると招待コードが生成されます。")
                        } else {
                            VStack(spacing: 10) {
                                ForEach(appState.groups) { group in
                                    HStack(spacing: 12) {
                                        Text(group.icon).font(.title)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(group.name).font(.headline)
                                            Text("\(group.memberIds.count)人 / 招待 \(group.inviteCode)")
                                                .font(.subheadline)
                                                .foregroundStyle(PetalogTheme.secondaryText)
                                        }
                                        Spacer()
                                    }
                                    .padding(12)
                                    .background(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                }
                            }
                        }
                    }
                }

                if initialMode != .join {
                    ControlSection(title: "グループを作る") {
                        VStack(spacing: 12) {
                            TextField("グループ名", text: $groupName)
                                .textFieldStyle(.roundedBorder)

                            HStack(spacing: 8) {
                                ForEach(["📘", "🏖", "🎒", "🎪", "🎂", "🎤"], id: \.self) { icon in
                                    Button(icon) { groupIcon = icon }
                                        .font(.title2)
                                        .frame(width: 42, height: 42)
                                        .background(icon == groupIcon ? PetalogTheme.primary.opacity(0.16) : .white)
                                        .clipShape(Circle())
                                }
                            }

                            Button {
                                Task {
                                    await appState.createGroup(name: groupName, icon: groupIcon)
                                    groupName = ""
                                }
                            } label: {
                                Label("グループを作る", systemImage: "person.badge.plus")
                            }
                            .buttonStyle(PrimaryActionButtonStyle())
                            .disabled(groupName.trimmedForPetalog.isEmpty)
                        }
                    }
                }

                if initialMode != .create {
                    ControlSection(title: "グループに参加する") {
                        VStack(spacing: 12) {
                            TextField("招待コード", text: $inviteCode)
                                .textInputAutocapitalization(.characters)
                                .textFieldStyle(.roundedBorder)
                            Button {
                                Task {
                                    await appState.joinGroup(inviteCode: inviteCode)
                                    inviteCode = ""
                                }
                            } label: {
                                Label("参加する", systemImage: "qrcode")
                            }
                            .buttonStyle(SecondaryActionButtonStyle())
                            .disabled(inviteCode.trimmedForPetalog.isEmpty)
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(PetalogTheme.background)
        .navigationTitle("グループ")
        .navigationBarTitleDisplayMode(.inline)
    }
}
