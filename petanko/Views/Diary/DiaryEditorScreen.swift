import SwiftUI
import UIKit

enum CanvasElementID: Hashable, Identifiable {
    case sticker(String)
    case text(String)
    case stamp(String)

    var id: String {
        switch self {
        case .sticker(let id): "sticker:\(id)"
        case .text(let id): "text:\(id)"
        case .stamp(let id): "stamp:\(id)"
        }
    }
}

private enum DiaryLayerMovement {
    case forward
    case backward
    case front
    case back
}

private enum DiaryEditorTab: String, CaseIterable, Identifiable {
    case autoArrange = "自動生成"
    case text = "文字"
    case stamp = "スタンプ"
    case background = "背景"

    var id: String { rawValue }
}



struct DiaryEditorScreen: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    let group: PetankoGroup
    @StateObject private var viewModel: DiaryViewModel
    @State private var draftDiary: DiaryPage?
    @State private var selectedElement: CanvasElementID?
    @State private var localLayouts: [String: StickerLayout] = [:]
    @State private var canvasSize: CGSize = .zero
    @State private var lockMessage: String?
    @State private var isSaving = false
    @State private var activeElement: CanvasElementID?
    @State private var isShowingFontPicker = false
    @State private var inputBuffer = DiaryTextInputBuffer()
    @State private var selectedEditorTab: DiaryEditorTab = .autoArrange
    @State private var isAutoArranging = false
    @State private var editorBottomSheetHeight: CGFloat = 0
    @State private var lockRenewalTask: Task<Void, Never>?


    init(group: PetankoGroup) {
        self.group = group
        _viewModel = StateObject(wrappedValue: DiaryViewModel(group: group))
    }

    var body: some View {
        VStack(spacing: 10) {
            if let lockMessage {
                Label(lockMessage, systemImage: "lock.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: AppRadius.chip))
            }

            if draftDiary != nil {
                AdaptiveEditableDiaryCanvas(
                    diary: draftDiaryBinding,
                    stickers: viewModel.stickers,
                    layouts: $localLayouts,
                    selectedElement: $selectedElement,
                    activeElement: $activeElement,
                    canvasSize: $canvasSize
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            } else {
                ProgressView("絵日記を読み込み中")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background {
            ZStack {
                PetankoMetalBackground()
                InteractivePopGestureDisabler()
                    .frame(width: 0, height: 0)
            }
        }
        .overlay(alignment: .bottom) {
            if draftDiary != nil {
                editorBottomSheet
                    .background {
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: EditorBottomSheetHeightPreferenceKey.self,
                                value: proxy.size.height
                            )
                        }
                    }
            }
        }
        .onPreferenceChange(EditorBottomSheetHeightPreferenceKey.self) { height in
            guard height.isFinite, abs(editorBottomSheetHeight - height) > 0.5 else { return }
            editorBottomSheetHeight = height
        }
        .navigationTitle("絵日記編集")
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
                Button {
                    guard let draftDiary else { return }
                    Task { await save(draftDiary) }
                } label: {
                    if isSaving {
                        ProgressView()
                    } else {
                        Label("保存", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(AppColors.accentPink)
                    }
                }
                .buttonStyle(.plain)
                .disabled(isSaving || lockMessage != nil || draftDiary == nil)
            }
        }
        .onAppear { viewModel.start() }
        .onDisappear {
            stopLockHeartbeat()
            viewModel.stop()
            if let user = appState.currentUser {
                Task { await viewModel.releaseEditLock(user: user) }
            }
        }
        .onChange(of: scenePhase) { _, newValue in
            guard newValue == .background else { return }
            stopLockHeartbeat()
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
            if let diary = draftDiary ?? viewModel.diary {
                seedLayouts(from: diary)
            }
        }
        .onChange(of: selectedElement) { _, element in
            switch element {
            case .text:
                selectedEditorTab = .text
            case .stamp:
                selectedEditorTab = .stamp
            case .sticker, nil:
                break
            }
        }
        .sheet(isPresented: $isShowingFontPicker) {
            DiaryFontPicker(
                selectedFontName: selectedFontNameBinding,
                isPresented: $isShowingFontPicker
            )
                .ignoresSafeArea()
        }
    }

    private var isStickerSelected: Bool {
        if case .sticker = selectedElement {
            return true
        }
        return false
    }


    @ViewBuilder
    private var editorBottomSheet: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                if selectedElement != nil {
                    selectedObjectSummary
                }

                if !isStickerSelected {
                    editorTabContent
                }



            }
            .controlSize(.regular)
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity)
            .background(.white)

            if selectedElement == nil {
                Rectangle()
                    .fill(AppColors.border.opacity(0.55))
                    .frame(height: 1)

                editorBottomTabBar
            }
        }
        .frame(maxWidth: .infinity)
        .background(.white)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: AppRadius.card,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: AppRadius.card,
                style: .continuous
            )
        )
        .shadow(color: .black.opacity(0.10), radius: 14, x: 0, y: -4)
        .ignoresSafeArea(.container, edges: .bottom)
    }

    private var editorBottomTabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 22) {
                ForEach(DiaryEditorTab.allCases) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.16)) {
                            selectedEditorTab = tab
                        }
                    } label: {
                        Text(tab.rawValue)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(selectedEditorTab == tab ? AppColors.accentPink : AppColors.mainText)
                            .padding(.horizontal, selectedEditorTab == tab ? 20 : 2)
                            .padding(.vertical, 10)
                            .frame(minWidth: 76)
                            .background {
                                Capsule()
                                    .fill(selectedEditorTab == tab ? AppColors.accentPink.opacity(0.15) : .clear)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity)
        .background(.white)
    }

    @ViewBuilder
    private var editorTabContent: some View {
        switch selectedEditorTab {
        case .autoArrange:
            VStack(alignment: .leading, spacing: 8) {

                Button {
                    autoArrangeDiary()
                } label: {
                    Text(isAutoArranging ? "自動配置中…" : "自動配置する")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(AppColors.burntOrange, in: RoundedRectangle(cornerRadius: AppRadius.chip, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(!canAutoArrange || isAutoArranging)
                .opacity(canAutoArrange && !isAutoArranging ? 1 : 0.42)
            }

        case .text:
            VStack(alignment: .leading, spacing: 9) {
                if case .text(let textID) = selectedElement {
                    textEditingControls(textID: textID)
                } else {
                    Button {
                        addText()
                    } label: {
                        Text("文字を追加")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(.black, in: RoundedRectangle(cornerRadius: AppRadius.chip, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }

        case .stamp:
            VStack(alignment: .leading, spacing: 9) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(["★", "♥", "!!", "→", "✦", "♪"], id: \.self) { stamp in
                            Button {
                                if case .stamp(let stampID) = selectedElement {
                                    // 選択中のスタンプを書き換える
                                    updateStamp(stampID) {
                                        $0.symbol = stamp
                                    }
                                } else {
                                    // 何も選択していないなら新規追加
                                    addStamp(stamp)
                                }
                            } label: {
                                Text(stamp)
                                    .font(.title3.weight(.bold))
                                    .frame(width: 50, height: 42)
                            }
                            .buttonStyle(.bordered)
                            .tint(AppColors.mainText)
                        }
                    }
                }

                if case .stamp(let stampID) = selectedElement {
                    HStack(spacing: 10) {
                        ColorPicker("スタンプ色", selection: selectedStampColorBinding, supportsOpacity: false)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppColors.mainText)

                        Spacer(minLength: 0)

                        deleteButton { deleteStamp(stampID) }
                    }
                }
            }

        case .background:
            VStack(alignment: .leading, spacing: 9) {

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(ScrapbookBackground.allCases) { background in
                            Button {
                                draftDiary?.background = background
                            } label: {
                                Text(background.title)
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 14)
                                    .frame(height: 42)
                            }
                            .buttonStyle(.bordered)
                            .tint(draftDiary?.background == background ? AppColors.burntOrange : AppColors.mainText)
                        }
                    }
                }
            }
        }
    }

    private var selectedObjectSummary: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {

                Spacer(minLength: 4)


                Button {
                    selectedElement = nil
                    activeElement = nil
                } label: {
                    Text("終了")
                }
                .buttonStyle(.bordered)
            }

            HStack(spacing: 6) {
                DiaryLayerActionButton(title: "前へ", systemImage: "arrow.up", isDisabled: !canMoveSelectedForward) {
                    moveSelectedLayer(.forward)
                }
                DiaryLayerActionButton(title: "後ろへ", systemImage: "arrow.down", isDisabled: !canMoveSelectedBackward) {
                    moveSelectedLayer(.backward)
                }
                DiaryLayerActionButton(title: "最前面", systemImage: "square.3.layers.3d.top.filled", isDisabled: !canMoveSelectedForward) {
                    moveSelectedLayer(.front)
                }
                DiaryLayerActionButton(title: "最背面", systemImage: "square.3.layers.3d.bottom.filled", isDisabled: !canMoveSelectedBackward) {
                    moveSelectedLayer(.back)
                }
            }
        }
    }

    private func textEditingControls(textID: String) -> some View {
        VStack(spacing: 9) {
            BufferedDiaryTextField(
                placeholder: "文字を入力",
                initialText: selectedText?.text ?? "",
                axis: .vertical,
                lineLimit: 2,
                onImmediateChange: { inputBuffer.textValues[textID] = $0 },
                onCommit: { value in
                    guard selectedText?.text != value else { return }
                    updateText(textID) { $0.text = value }
                }
            )
            .id(textID)
            .textFieldStyle(.plain)
            .metalTextField()

            HStack(spacing: 8) {
                Button {
                    isShowingFontPicker = true
                } label: {
                    Text(selectedFontDisplayName)
                        .lineLimit(1)
                }
                .buttonStyle(.bordered)

                ColorPicker("文字色", selection: selectedTextColorBinding, supportsOpacity: false)
                    .labelsHidden()

                if !(selectedText?.fontName ?? "").isEmpty {
                    Button {
                        updateText(textID) { $0.fontName = "" }
                    } label: {
                        Text("標準")
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("システムフォントに戻す")
                }

                Spacer(minLength: 0)
                deleteButton { deleteText(textID) }
            }
        }
    }

    private func deleteButton(action: @escaping () -> Void) -> some View {
        Button(role: .destructive, action: action) {
            Label("削除", systemImage: "trash")
        }
        .buttonStyle(.bordered)
    }

    private func seedLayouts(from diary: DiaryPage) {
        var next = localLayouts
        let activeStickerIDs = Set(viewModel.stickers.map(\.id))
        next = next.filter { activeStickerIDs.contains($0.key) }
        for sticker in viewModel.stickers where next[sticker.id] == nil {
            next[sticker.id] = diary.stickerLayout.first(where: { $0.stickerId == sticker.id }) ?? sticker.layout
        }
        localLayouts = next
    }

    private func lockIfPossible() async {
        guard lockMessage == nil, let user = appState.currentUser else { return }
        let acquired = await viewModel.acquireEditLock(user: user)
        if !acquired {
            stopLockHeartbeat()
            lockMessage = "他のメンバーが編集中です。しばらくしてからもう一度開いてください。"
        } else {
            startLockHeartbeat(user: user)
        }
    }

    private func save(_ diary: DiaryPage) async {
        isSaving = true
        var page = diary
        inputBuffer.apply(to: &page)
        var layouts = localLayouts
        let order = diaryLayerEntries(diary: page, stickers: viewModel.stickers, layouts: layouts).map(\.element)
        applyDiaryLayerOrder(order, diary: &page, stickers: viewModel.stickers, layouts: &layouts)
        let stickerIDs = Set(viewModel.stickers.map(\.id))
        page.stickerLayout = layouts.values
            .filter { stickerIDs.contains($0.stickerId) }
            .sorted { $0.zIndex < $1.zIndex }
        draftDiary = page
        localLayouts = layouts
        await viewModel.saveDiary(page)
        isSaving = false
        stopLockHeartbeat()
        dismiss()
    }

    private func startLockHeartbeat(user: AppUser) {
        stopLockHeartbeat()
        lockRenewalTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30 * 1_000_000_000)
                guard !Task.isCancelled else { return }
                let renewed = await viewModel.renewEditLock(user: user)
                if !renewed {
                    lockMessage = "編集ロックが切れました。もう一度開き直してください。"
                    stopLockHeartbeat()
                    return
                }
            }
        }
    }

    private func stopLockHeartbeat() {
        lockRenewalTask?.cancel()
        lockRenewalTask = nil
    }

    private var selectedSticker: StickerPost? {
        guard case .sticker(let id) = selectedElement else { return nil }
        return viewModel.stickers.first { $0.id == id }
    }

    private var selectedTextID: String? {
        guard case .text(let id) = selectedElement else { return nil }
        return id
    }

    private var layerEntries: [DiaryLayerEntry] {
        diaryLayerEntries(
            diary: draftDiary ?? emptyDiary,
            stickers: viewModel.stickers,
            layouts: localLayouts
        )
    }

    private var selectedLayerEntry: DiaryLayerEntry? {
        guard let selectedElement else { return nil }
        return layerEntries.first { $0.element == selectedElement }
    }

    private var selectedLayerIndex: Int? {
        guard let selectedElement else { return nil }
        return layerEntries.firstIndex { $0.element == selectedElement }
    }

    private var canMoveSelectedForward: Bool {
        guard let selectedLayerIndex else { return false }
        return selectedLayerIndex > 0
    }

    private var canMoveSelectedBackward: Bool {
        guard let selectedLayerIndex else { return false }
        return selectedLayerIndex < layerEntries.count - 1
    }

    private var selectedText: DiaryTextItem? {
        guard let selectedTextID else { return nil }
        return draftDiary?.textItems.first { $0.id == selectedTextID }
    }

    private var selectedStamp: DiaryStampItem? {
        guard case .stamp(let id) = selectedElement else { return nil }
        return draftDiary?.stampItems.first { $0.id == id }
    }

    private var selectedFontDisplayName: String {
        guard let fontName = selectedText?.fontName, !fontName.isEmpty else { return "システム" }
        return UIFont(name: fontName, size: 24)?.familyName ?? fontName
    }

    private var selectedFontNameBinding: Binding<String> {
        Binding(
            get: { selectedText?.fontName ?? "" },
            set: { value in
                guard let selectedTextID else { return }
                updateText(selectedTextID) { $0.fontName = value }
            }
        )
    }

    private var draftDiaryBinding: Binding<DiaryPage> {
        Binding(
            get: { draftDiary ?? emptyDiary },
            set: { draftDiary = $0 }
        )
    }

    private var selectedTextColorBinding: Binding<Color> {
        Binding(
            get: {
                Color(uiColor: UIColor(hex: selectedText?.colorHex ?? DiaryTextItem.defaultColorHex) ?? UIColor(AppColors.mainText))
            },
            set: { color in
                guard let selectedTextID else { return }
                updateText(selectedTextID) { $0.colorHex = UIColor(color).petankoHexString }
            }
        )
    }

    private var selectedStampColorBinding: Binding<Color> {
        Binding(
            get: {
                Color(uiColor: UIColor(hex: selectedStamp?.colorHex ?? DiaryStampItem.defaultColorHex) ?? UIColor(AppColors.mainText))
            },
            set: { color in
                guard case .stamp(let id) = selectedElement else { return }
                updateStamp(id) { $0.colorHex = UIColor(color).petankoHexString }
            }
        )
    }

    private var nextZIndex: Int {
        diaryLayerEntries(
            diary: draftDiary ?? emptyDiary,
            stickers: viewModel.stickers,
            layouts: localLayouts
        )
        .map(\.zIndex)
        .max()
        .map { $0 + 1 } ?? 0
    }

    private var emptyDiary: DiaryPage {
        DiaryPage(id: "", groupId: group.id, dateKey: Date().petankoDateKey, title: "")
    }

    private var insertionPoint: CGPoint {
        let width = canvasSize.width > 0 ? canvasSize.width : DiaryCanvasMetrics.logicalSize.width
        let height = canvasSize.height > 0 ? canvasSize.height : DiaryCanvasMetrics.logicalSize.height
        return CGPoint(x: width / 2, y: height / 2)
    }

    private var canAutoArrange: Bool {
        guard let draftDiary else { return false }
        return !draftDiary.textItems.isEmpty || !draftDiary.stampItems.isEmpty || !viewModel.stickers.isEmpty
    }

    private func autoArrangeDiary() {
        guard var page = draftDiary, canAutoArrange, !isAutoArranging else { return }
        inputBuffer.apply(to: &page)
        let size = normalizedCanvasSize
        let stickers = viewModel.stickers
        let layouts = localLayouts
        isAutoArranging = true
        activeElement = nil
        selectedElement = nil

        Task {
            await Task.yield()
            let result = DiaryAutoArranger.arrange(
                diary: page,
                stickers: stickers,
                layouts: layouts,
                canvasSize: size
            )

            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                draftDiary = result.diary
                localLayouts = result.layouts
            }
            isAutoArranging = false
        }
    }

    private var normalizedCanvasSize: CGSize {
        DiaryCanvasMetrics.logicalSize
    }

    private func addText() {
        let item = DiaryTextItem(
            text: "新しい文字",
            x: insertionPoint.x,
            y: insertionPoint.y,
            colorHex: randomDiaryAccentColorHex,
            zIndex: nextZIndex
        )
        draftDiary?.textItems.append(item)
        activeElement = nil
        selectedElement = .text(item.id)
    }

    private func addStamp(_ symbol: String) {
        let item = DiaryStampItem(
            symbol: symbol,
            colorHex: randomDiaryAccentColorHex,
            x: insertionPoint.x,
            y: insertionPoint.y,
            zIndex: nextZIndex
        )
        draftDiary?.stampItems.append(item)
        activeElement = nil
        selectedElement = .stamp(item.id)
    }

    private var randomDiaryAccentColorHex: String {
        [
            "#1F1B18",
            "#C2410C",
            "#E11D48",
            "#BE185D",
            "#7C3AED",
            "#2563EB",
            "#0891B2",
            "#047857",
            "#65A30D",
            "#CA8A04",
            "#EA580C"
        ].randomElement() ?? DiaryTextItem.defaultColorHex
    }

    private func moveSelectedLayer(_ movement: DiaryLayerMovement) {
        guard var page = draftDiary,
              let selectedElement,
              let currentIndex = selectedLayerIndex else { return }

        var order = layerEntries.map(\.element)
        switch movement {
        case .forward:
            guard currentIndex > 0 else { return }
            order.swapAt(currentIndex, currentIndex - 1)
        case .backward:
            guard currentIndex < order.count - 1 else { return }
            order.swapAt(currentIndex, currentIndex + 1)
        case .front:
            guard currentIndex > 0 else { return }
            order.remove(at: currentIndex)
            order.insert(selectedElement, at: 0)
        case .back:
            guard currentIndex < order.count - 1 else { return }
            order.remove(at: currentIndex)
            order.append(selectedElement)
        }

        var layouts = localLayouts
        withAnimation(.easeInOut(duration: 0.18)) {
            applyDiaryLayerOrder(order, diary: &page, stickers: viewModel.stickers, layouts: &layouts)
            draftDiary = page
            localLayouts = layouts
        }
    }

    private func updateText(_ id: String, mutate: (inout DiaryTextItem) -> Void) {
        guard var page = draftDiary,
              let index = page.textItems.firstIndex(where: { $0.id == id }) else { return }
        mutate(&page.textItems[index])
        draftDiary = page
    }

    private func deleteText(_ id: String) {
        inputBuffer.textValues.removeValue(forKey: id)
        draftDiary?.textItems.removeAll { $0.id == id }
        activeElement = nil
        selectedElement = nil
    }

    private func updateStamp(_ id: String, mutate: (inout DiaryStampItem) -> Void) {
        guard var page = draftDiary,
              let index = page.stampItems.firstIndex(where: { $0.id == id }) else { return }
        mutate(&page.stampItems[index])
        draftDiary = page
    }

    private func deleteStamp(_ id: String) {
        draftDiary?.stampItems.removeAll { $0.id == id }
        activeElement = nil
        selectedElement = nil
    }

    private func deleteSelectedSticker(_ sticker: StickerPost) async {
        guard let user = appState.currentUser else { return }
        activeElement = nil
        selectedElement = nil
        localLayouts.removeValue(forKey: sticker.id)
        draftDiary?.stickerLayout.removeAll { $0.stickerId == sticker.id }
        await viewModel.deleteSticker(sticker, user: user)
    }
}

@MainActor
private final class DiaryTextInputBuffer {
    var textValues: [String: String] = [:]

    func apply(to diary: inout DiaryPage) {
        for (id, text) in textValues {
            guard let index = diary.textItems.firstIndex(where: { $0.id == id }) else { continue }
            diary.textItems[index].text = text
        }
    }
}

private struct BufferedDiaryTextField: View {
    let placeholder: String
    let initialText: String
    var axis: Axis = .horizontal
    var lineLimit: Int = 1
    let onImmediateChange: (String) -> Void
    let onCommit: (String) -> Void

    @State private var text: String
    @State private var pendingCommit: Task<Void, Never>?
    @FocusState private var isFocused: Bool

    init(
        placeholder: String,
        initialText: String,
        axis: Axis = .horizontal,
        lineLimit: Int = 1,
        onImmediateChange: @escaping (String) -> Void,
        onCommit: @escaping (String) -> Void
    ) {
        self.placeholder = placeholder
        self.initialText = initialText
        self.axis = axis
        self.lineLimit = lineLimit
        self.onImmediateChange = onImmediateChange
        self.onCommit = onCommit
        _text = State(initialValue: initialText)
    }

    var body: some View {
        TextField(placeholder, text: $text, axis: axis)
            .lineLimit(lineLimit)
            .focused($isFocused)
            .onChange(of: text) { _, value in
                onImmediateChange(value)
                scheduleCommit(value)
            }
            .onChange(of: initialText) { _, value in
                guard !isFocused, text != value else { return }
                text = value
            }
            .onChange(of: isFocused) { _, focused in
                if !focused {
                    commitImmediately()
                }
            }
            .onDisappear {
                commitImmediately()
            }
    }

    private func scheduleCommit(_ value: String) {
        pendingCommit?.cancel()
        pendingCommit = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(140))
            guard !Task.isCancelled else { return }
            onCommit(value)
        }
    }

    private func commitImmediately() {
        pendingCommit?.cancel()
        onCommit(text)
    }
}

private struct AdaptiveEditableDiaryCanvas: View {
    @Binding var diary: DiaryPage
    let stickers: [StickerPost]
    @Binding var layouts: [String: StickerLayout]
    @Binding var selectedElement: CanvasElementID?
    @Binding var activeElement: CanvasElementID?
    @Binding var canvasSize: CGSize

    var body: some View {
        GeometryReader { proxy in
            let logicalSize = DiaryCanvasMetrics.logicalSize
            let scale = min(
                max(proxy.size.width, 1) / logicalSize.width,
                max(proxy.size.height, 1) / logicalSize.height
            )

            EditableDiaryCanvas(
                diary: $diary,
                stickers: stickers,
                layouts: $layouts,
                selectedElement: $selectedElement,
                activeElement: $activeElement,
                canvasSize: $canvasSize
            )
            .frame(width: logicalSize.width, height: logicalSize.height)
            .scaleEffect(scale, anchor: .center)
            .position(
                x: proxy.size.width / 2,
                y: logicalSize.height * scale / 2
            )
        }
    }
}

struct EditableDiaryCanvas: View {
    @Binding var diary: DiaryPage
    let stickers: [StickerPost]
    @Binding var layouts: [String: StickerLayout]
    @Binding var selectedElement: CanvasElementID?
    @Binding var activeElement: CanvasElementID?
    @Binding var canvasSize: CGSize

    @State private var elementFrames: [CanvasElementID: CGRect] = [:]

    var body: some View {
        GeometryReader { _ in
            ZStack {
                DiaryBackgroundView(background: diary.background)
                    .contentShape(Rectangle())
                    .zIndex(-2_000_000_000_000)

                ForEach(diary.textItems) { item in
                    let element = CanvasElementID.text(item.id)
                    DiaryTextVisual(item: item)
                        .padding(6)
                        .overlay {
                            if selectedElement == element {
                                RoundedRectangle(cornerRadius: AppRadius.chip)
                                    .stroke(AppColors.mainText, lineWidth: 1.5)
                            }
                        }
                        .scaleEffect(item.scale)
                        .rotationEffect(.degrees(item.rotation))
                        .diaryElementFrame(element)
                        .position(x: item.x, y: item.y)
                        .allowsHitTesting(false)
                        .zIndex(Double(item.zIndex))
                }

                ForEach(diary.stampItems) { item in
                    let element = CanvasElementID.stamp(item.id)
                    Text(item.symbol)
                        .font(.largeTitle.bold())
                        .foregroundStyle(Color(uiColor: UIColor(hex: item.colorHex) ?? UIColor(AppColors.mainText)))
                        .padding(8)
                        .overlay {
                            if selectedElement == element {
                                Circle().stroke(AppColors.mainText, lineWidth: 1.5)
                            }
                        }
                        .scaleEffect(item.scale)
                        .rotationEffect(.degrees(item.rotation))
                        .diaryElementFrame(element)
                        .position(x: item.x, y: item.y)
                        .allowsHitTesting(false)
                        .zIndex(Double(item.zIndex))
                }

                ForEach(stickers) { sticker in
                    let layout = layouts[sticker.id] ?? sticker.layout
                    let element = CanvasElementID.sticker(sticker.id)
                    RemoteStickerView(sticker: sticker, size: DiaryCanvasMetrics.stickerBaseSize)
                        .overlay {
                            if selectedElement == element {
                                RoundedRectangle(cornerRadius: AppRadius.card)
                                    .stroke(AppColors.mainText, lineWidth: 1.5)
                            }
                        }
                        .scaleEffect(layout.scale)
                        .rotationEffect(.degrees(layout.rotation))
                        .position(
                            x: DiaryCanvasMetrics.logicalSize.width / 2 + layout.x,
                            y: DiaryCanvasMetrics.logicalSize.height / 2 + layout.y
                        )
                        .diaryElementFrame(element)
                        .allowsHitTesting(false)
                        .zIndex(Double(layout.zIndex))
                }

                interactionLayer
            }
            .coordinateSpace(name: "diaryCanvas")
            .contentShape(Rectangle())
            .onPreferenceChange(DiaryElementFramePreferenceKey.self) { frames in
                guard frames != elementFrames else { return }
                elementFrames = frames
            }
            .simultaneousGesture(
                SpatialTapGesture()
                    .onEnded { value in
                        selectElement(at: value.location)
                    }
            )
            .onAppear {
                if canvasSize != DiaryCanvasMetrics.logicalSize {
                    canvasSize = DiaryCanvasMetrics.logicalSize
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .stroke(AppColors.border, lineWidth: 0.8)
        }
    }

    @ViewBuilder
    private var interactionLayer: some View {
        let entries = diaryLayerEntries(
            diary: diary,
            stickers: stickers,
            layouts: layouts
        )

        ForEach(entries, id: \.element) { entry in
            interactionRegion(
                for: entry.element,
                zIndex: entry.zIndex
            )
        }
    }
    private func interactionHitSize(
        for element: CanvasElementID,
        frame: CGRect
    ) -> CGSize {
        switch element {
        case .stamp:
            // 選択中ならピンチしやすい領域に拡大
            if selectedElement == element {
                return CGSize(
                    width: max(frame.width, 100),
                    height: max(frame.height, 100)
                )
            }

            return frame.size

        default:
            return frame.size
        }
    }
    @ViewBuilder
    private func interactionRegion(
        for element: CanvasElementID,
        zIndex: Int
    ) -> some View {
        if let frame = interactionFrame(for: element),
           frame.width > 0,
           frame.height > 0,
           frame.width.isFinite,
           frame.height.isFinite {

            let hitSize = interactionHitSize(
                for: element,
                frame: frame
            )

            Color.clear
                .frame(
                    width: hitSize.width,
                    height: hitSize.height
                )
                .contentShape(Rectangle())
                .modifier(
                    interactionModifier(
                        for: element,
                        zIndex: zIndex
                    )
                )
                .position(
                    x: frame.midX,
                    y: frame.midY
                )
        }
    }
    private func interactionModifier(
        for element: CanvasElementID,
        zIndex: Int
    ) -> DiaryElementInteractionModifier {

        switch element {

        case .text(let id):
            let item = diary.textItems.first { $0.id == id }

            return DiaryElementInteractionModifier(
                element: element,
                zIndex: zIndex,
                x: item?.x ?? 0,
                y: item?.y ?? 0,
                scale: item?.scale ?? 1,
                rotation: item?.rotation ?? 0,
                scaleRange: 0.5...3,
                selectedElement: $selectedElement,
                activeElement: $activeElement,
                allowsDirectHitTesting: true,
                updatePosition: { x, y in
                    updateText(id) {
                        $0.x = x
                        $0.y = y
                    }
                },
                updateScale: { scale in
                    updateText(id) {
                        $0.scale = scale
                    }
                },
                updateRotation: { rotation in
                    updateText(id) {
                        $0.rotation = rotation
                    }
                }
            )

        case .stamp(let id):
            let item = diary.stampItems.first { $0.id == id }

            return DiaryElementInteractionModifier(
                element: element,
                zIndex: zIndex,
                x: item?.x ?? 0,
                y: item?.y ?? 0,
                scale: item?.scale ?? 1,
                rotation: item?.rotation ?? 0,
                scaleRange: 0.5...3,
                selectedElement: $selectedElement,
                activeElement: $activeElement,
                allowsDirectHitTesting: true,
                updatePosition: { x, y in
                    updateStamp(id) {
                        $0.x = x
                        $0.y = y
                    }
                },
                updateScale: { scale in
                    updateStamp(id) {
                        $0.scale = scale
                    }
                },
                updateRotation: { rotation in
                    updateStamp(id) {
                        $0.rotation = rotation
                    }
                }
            )

        case .sticker(let id):
            let sticker = stickers.first { $0.id == id }

            let layout: StickerLayout? = sticker.map {
                layouts[id]
                    ?? diary.stickerLayout.first {
                        $0.stickerId == id
                    }
                    ?? $0.layout
            }

            return DiaryElementInteractionModifier(
                element: element,
                zIndex: zIndex,
                x: layout?.x ?? 0,
                y: layout?.y ?? 0,
                scale: layout?.scale ?? 1,
                rotation: layout?.rotation ?? 0,
                scaleRange: 0.55...1.8,
                selectedElement: $selectedElement,
                activeElement: $activeElement,
                allowsDirectHitTesting: true,
                updatePosition: { x, y in
                    guard let sticker else { return }

                    updateSticker(sticker) {
                        $0.x = x
                        $0.y = y
                    }
                },
                updateScale: { scale in
                    guard let sticker else { return }

                    updateSticker(sticker) {
                        $0.scale = scale
                    }
                },
                updateRotation: { rotation in
                    guard let sticker else { return }

                    updateSticker(sticker) {
                        $0.rotation = rotation
                    }
                }
            )
        }
    }
    private func selectElement(at location: CGPoint) {
        let elements = hitElements(at: location)

        guard !elements.isEmpty else {
            selectedElement = nil
            activeElement = nil
            return
        }

        if let selectedElement,
           let currentIndex = elements.firstIndex(of: selectedElement) {

            let nextIndex = (currentIndex + 1) % elements.count
            self.selectedElement = elements[nextIndex]

        } else {
            selectedElement = elements[0]
        }

        activeElement = nil
    }

    private func hitElements(at location: CGPoint) -> [CanvasElementID] {
        diaryLayerEntries(
            diary: diary,
            stickers: stickers,
            layouts: layouts
        )
        .filter { entry in
            interactionFrame(for: entry.element)?
                .insetBy(dx: -8, dy: -8)
                .contains(location) == true
        }
        .map(\.element)
    }
    private func interactionFrame(for element: CanvasElementID) -> CGRect? {
        if case .sticker(let id) = element {
            return stickerInteractionFrame(id: id)
        }
        return elementFrames[element]
    }

    private func stickerInteractionFrame(id: String) -> CGRect? {
        guard let sticker = stickers.first(where: { $0.id == id }) else { return nil }
        let layout = layouts[id] ?? diary.stickerLayout.first(where: { $0.stickerId == id }) ?? sticker.layout
        let baseSize = DiaryCanvasMetrics.stickerBaseSize
        let size = rotatedSize(width: baseSize * layout.scale, height: baseSize * layout.scale, degrees: layout.rotation)
        let center = CGPoint(
            x: canvasSize.width / 2 + layout.x,
            y: canvasSize.height / 2 + layout.y
        )
        return CGRect(
            x: center.x - size.width / 2,
            y: center.y - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    private func rotatedSize(width: Double, height: Double, degrees: Double) -> CGSize {
        let radians = degrees * .pi / 180
        let rotatedWidth = abs(width * cos(radians)) + abs(height * sin(radians))
        let rotatedHeight = abs(width * sin(radians)) + abs(height * cos(radians))
        return CGSize(width: rotatedWidth, height: rotatedHeight)
    }

    private func updateText(_ id: String, mutate: (inout DiaryTextItem) -> Void) {
        guard let index = diary.textItems.firstIndex(where: { $0.id == id }) else { return }
        mutate(&diary.textItems[index])
    }

    private func updateStamp(_ id: String, mutate: (inout DiaryStampItem) -> Void) {
        guard let index = diary.stampItems.firstIndex(where: { $0.id == id }) else { return }
        mutate(&diary.stampItems[index])
    }

    private func updateSticker(_ sticker: StickerPost, mutate: (inout StickerLayout) -> Void) {
        var layout = layouts[sticker.id] ?? sticker.layout
        mutate(&layout)
        layouts[sticker.id] = layout
    }

    private func position(for element: CanvasElementID) -> CGPoint? {
        switch element {
        case .text(let id):
            guard let item = diary.textItems.first(where: { $0.id == id }) else { return nil }
            return CGPoint(x: item.x, y: item.y)
        case .stamp(let id):
            guard let item = diary.stampItems.first(where: { $0.id == id }) else { return nil }
            return CGPoint(x: item.x, y: item.y)
        case .sticker(let id):
            guard let sticker = stickers.first(where: { $0.id == id }) else { return nil }
            let layout = layouts[id] ?? diary.stickerLayout.first(where: { $0.stickerId == id }) ?? sticker.layout
            return CGPoint(x: layout.x, y: layout.y)
        }
    }

    private func scale(for element: CanvasElementID) -> Double? {
        switch element {
        case .text(let id):
            guard let item = diary.textItems.first(where: { $0.id == id }) else { return nil }
            return item.scale
        case .stamp(let id):
            guard let item = diary.stampItems.first(where: { $0.id == id }) else { return nil }
            return item.scale
        case .sticker(let id):
            guard let sticker = stickers.first(where: { $0.id == id }) else { return nil }
            let layout = layouts[id] ?? diary.stickerLayout.first(where: { $0.stickerId == id }) ?? sticker.layout
            return layout.scale
        }
    }

    private func clampedScale(_ scale: Double, for element: CanvasElementID) -> Double {
        let range: ClosedRange<Double>
        switch element {
        case .text, .stamp:
            range = 0.5...3
        case .sticker:
            range = 0.55...1.8
        }
        return min(range.upperBound, max(range.lowerBound, scale))
    }

    private func updateScale(for element: CanvasElementID, scale: Double) {
        switch element {
        case .text(let id):
            updateText(id) { $0.scale = scale }
        case .stamp(let id):
            updateStamp(id) { $0.scale = scale }
        case .sticker(let id):
            guard let sticker = stickers.first(where: { $0.id == id }) else { return }
            updateSticker(sticker) { $0.scale = scale }
        }
    }

    private func updatePosition(for element: CanvasElementID, x: Double, y: Double) {
        switch element {
        case .text(let id):
            updateText(id) {
                $0.x = x
                $0.y = y
            }
        case .stamp(let id):
            updateStamp(id) {
                $0.x = x
                $0.y = y
            }
        case .sticker(let id):
            guard let sticker = stickers.first(where: { $0.id == id }) else { return }
            updateSticker(sticker) {
                $0.x = x
                $0.y = y
            }
        }
    }
}

private struct DiaryElementInteractionModifier: ViewModifier {
    let element: CanvasElementID
    let zIndex: Int
    let x: Double
    let y: Double
    let scale: Double
    let rotation: Double
    let scaleRange: ClosedRange<Double>
    @Binding var selectedElement: CanvasElementID?
    @Binding var activeElement: CanvasElementID?
    var raisesWhenActive = false
    var allowsDirectHitTesting = true
    var selectsOnInteraction = true
    var allowsDragGesture = true
    var allowsScaleGesture = true
    let updatePosition: (Double, Double) -> Void
    let updateScale: (Double) -> Void
    let updateRotation: (Double) -> Void

    @State private var dragOrigin: CGSize?
    @State private var scaleOrigin: Double?
    @State private var rotationOrigin: Double?
    @State private var isDragging = false
    @State private var isScaling = false
    @State private var isRotating = false

    private var isActive: Bool { activeElement == element }
    private var isDimmed: Bool { activeElement != nil && !isActive }

    @ViewBuilder
    func body(content: Content) -> some View {
        let base = interactionBase(content)
        if allowsDragGesture && allowsScaleGesture {
            base
                .highPriorityGesture(dragGesture)
                .simultaneousGesture(scaleGesture)
                .simultaneousGesture(rotationGesture)
        } else if allowsDragGesture {
            base
                .highPriorityGesture(dragGesture)
                .simultaneousGesture(rotationGesture)
        } else if allowsScaleGesture {
            base
                .simultaneousGesture(scaleGesture)
                .simultaneousGesture(rotationGesture)
        } else {
            base
                .simultaneousGesture(rotationGesture)
        }
    }

    private var canReceiveInteraction: Bool {
        guard allowsDirectHitTesting else {
            return false
        }

        if let selectedElement {
            return selectedElement == element
        }

        return true
    }

    private func interactionBase(_ content: Content) -> some View {
        content
            .opacity(isDimmed ? 0.25 : 1)
            .zIndex(displayZIndex)
            .allowsHitTesting(canReceiveInteraction)
            .animation(.easeOut(duration: 0.15), value: isDimmed)
    }

    private var displayZIndex: Double {
        if isActive && raisesWhenActive { return 1_000_000_000_000 }
        if isDimmed { return -1_000_000_000_000 + Double(zIndex) }
        return Double(zIndex)
    }

    private var dragGesture: some Gesture {
        DragGesture(
            minimumDistance: 0,
            coordinateSpace: .named("diaryCanvas")
        )
        .onChanged { value in
            let origin = dragOrigin ?? CGSize(width: x, height: y)

            if dragOrigin == nil {
                dragOrigin = origin
            }

            beginInteraction(.drag)

            updatePosition(
                origin.width + value.translation.width,
                origin.height + value.translation.height
            )
        }
        .onEnded { value in

            dragOrigin = nil
            endInteraction(.drag)
        }
    }
    private var scaleGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                beginInteraction(.scale)
                let origin = scaleOrigin ?? scale
                if scaleOrigin == nil { scaleOrigin = origin }
                updateScale(min(scaleRange.upperBound, max(scaleRange.lowerBound, origin * value)))
            }
            .onEnded { _ in
                scaleOrigin = nil
                endInteraction(.scale)
            }
    }

    private var rotationGesture: some Gesture {
        RotationGesture()
            .onChanged { value in
                beginInteraction(.rotation)
                let origin = rotationOrigin ?? rotation
                if rotationOrigin == nil { rotationOrigin = origin }
                updateRotation(origin + value.degrees)
            }
            .onEnded { value in
                let origin = rotationOrigin ?? rotation
                updateRotation(normalizedAngle(origin + value.degrees))
                rotationOrigin = nil
                endInteraction(.rotation)
            }
    }

    private enum InteractionKind {
        case drag
        case scale
        case rotation
    }

    private func beginInteraction(_ kind: InteractionKind) {
        if selectedElement != element {
            selectedElement = element
        }

        if activeElement != element {
            activeElement = element
        }

        switch kind {
        case .drag:
            isDragging = true
        case .scale:
            isScaling = true
        case .rotation:
            isRotating = true
        }
    }

    private func endInteraction(_ kind: InteractionKind) {
        switch kind {
        case .drag: isDragging = false
        case .scale: isScaling = false
        case .rotation: isRotating = false
        }

        let anotherGestureIsActive: Bool
        switch kind {
        case .drag:
            anotherGestureIsActive = isScaling || isRotating
        case .scale:
            anotherGestureIsActive = isDragging || isRotating
        case .rotation:
            anotherGestureIsActive = isDragging || isScaling
        }
        if !anotherGestureIsActive {
            activeElement = nil
        }
    }

    private func normalizedAngle(_ angle: Double) -> Double {
        guard angle.isFinite else { return 0 }
        var result = angle.truncatingRemainder(dividingBy: 360)
        if result > 180 { result -= 360 }
        if result < -180 { result += 360 }
        return result
    }
}

private struct DiaryElementFramePreferenceKey: PreferenceKey {
    static var defaultValue: [CanvasElementID: CGRect] = [:]

    static func reduce(
        value: inout [CanvasElementID: CGRect],
        nextValue: () -> [CanvasElementID: CGRect]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private struct EditorBottomSheetHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private extension View {
    func diaryElementFrame(_ element: CanvasElementID) -> some View {
        background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: DiaryElementFramePreferenceKey.self,
                    value: [element: proxy.frame(in: .named("diaryCanvas"))]
                )
            }
        }
    }
}

private struct DiaryLayerEntry: Identifiable {
    let element: CanvasElementID
    let title: String
    let detail: String
    let systemImage: String
    let zIndex: Int
    let sequence: Int

    var id: String { element.id }
}

private func diaryLayerEntries(
    diary: DiaryPage,
    stickers: [StickerPost],
    layouts: [String: StickerLayout]
) -> [DiaryLayerEntry] {
    var entries: [DiaryLayerEntry] = []
    var sequence = 0

    for item in diary.textItems {
        entries.append(DiaryLayerEntry(
            element: .text(item.id),
            title: item.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "空の文字" : item.text,
            detail: "文字",
            systemImage: "textformat",
            zIndex: item.zIndex,
            sequence: sequence
        ))
        sequence += 1
    }

    for item in diary.stampItems {
        entries.append(DiaryLayerEntry(
            element: .stamp(item.id),
            title: item.symbol,
            detail: "スタンプ",
            systemImage: "star.fill",
            zIndex: item.zIndex,
            sequence: sequence
        ))
        sequence += 1
    }

    for sticker in stickers {
        let layout = layouts[sticker.id] ?? diary.stickerLayout.first(where: { $0.stickerId == sticker.id }) ?? sticker.layout
        entries.append(DiaryLayerEntry(
            element: .sticker(sticker.id),
            title: sticker.comment.isEmpty ? "写真" : sticker.comment,
            detail: sticker.authorName,
            systemImage: "photo.fill",
            zIndex: layout.zIndex,
            sequence: sequence
        ))
        sequence += 1
    }

    return entries.sorted {
        if $0.zIndex != $1.zIndex { return $0.zIndex > $1.zIndex }
        return $0.sequence > $1.sequence
    }
}

private func applyDiaryLayerOrder(
    _ frontToBack: [CanvasElementID],
    diary: inout DiaryPage,
    stickers: [StickerPost],
    layouts: inout [String: StickerLayout]
) {
    for (index, element) in frontToBack.enumerated() {
        let zIndex = frontToBack.count - index - 1
        switch element {
        case .text(let id):
            guard let itemIndex = diary.textItems.firstIndex(where: { $0.id == id }) else { continue }
            diary.textItems[itemIndex].zIndex = zIndex
        case .stamp(let id):
            guard let itemIndex = diary.stampItems.firstIndex(where: { $0.id == id }) else { continue }
            diary.stampItems[itemIndex].zIndex = zIndex
        case .sticker(let id):
            guard let sticker = stickers.first(where: { $0.id == id }) else { continue }
            var layout = layouts[id] ?? diary.stickerLayout.first(where: { $0.stickerId == id }) ?? sticker.layout
            layout.zIndex = zIndex
            layouts[id] = layout
        }
    }
}

private struct DiaryAutoArrangeResult {
    var diary: DiaryPage
    var layouts: [String: StickerLayout]
}

private struct AutoArrangeElement: Identifiable {
    enum Kind {
        case sticker
        case text
        case stamp
    }

    let id: CanvasElementID
    let kind: Kind
    let baseSize: CGSize
    var center: CGPoint
    var rotation: Double
    var zIndex: Int
    var scale: Double

    var frame: CGRect {
        let radians = rotation * .pi / 180
        let width = baseSize.width * scale
        let height = baseSize.height * scale
        let rotatedWidth = abs(width * cos(radians)) + abs(height * sin(radians))
        let rotatedHeight = abs(width * sin(radians)) + abs(height * cos(radians))
        return CGRect(
            x: center.x - rotatedWidth / 2,
            y: center.y - rotatedHeight / 2,
            width: rotatedWidth,
            height: rotatedHeight
        )
    }
}

private enum DiaryAutoArranger {
    private static let safeInset: CGFloat = 14
    private static let movementSteps: [CGFloat] = [18, 9]
    private static let maximumPassesPerStep = 1
    private static let candidateDirections: [CGVector] = [
        CGVector(dx: 1, dy: 0),
        CGVector(dx: -1, dy: 0),
        CGVector(dx: 0, dy: 1),
        CGVector(dx: 0, dy: -1),
        CGVector(dx: 1, dy: 1),
        CGVector(dx: 1, dy: -1),
        CGVector(dx: -1, dy: 1),
        CGVector(dx: -1, dy: -1)
    ]

    static func arrange(
        diary: DiaryPage,
        stickers: [StickerPost],
        layouts: [String: StickerLayout],
        canvasSize: CGSize
    ) -> DiaryAutoArrangeResult {
        let size = DiaryCanvasMetrics.logicalSize
        let originalElements = makeElements(diary: diary, stickers: stickers, layouts: layouts, canvasSize: size)
        guard !originalElements.isEmpty else {
            return DiaryAutoArrangeResult(diary: diary, layouts: layouts)
        }

        var bestElements = originalElements
        var bestScore = -Double.infinity
        let trialCount = min(max(4 + originalElements.count / 3, 4), 10)
        for trialIndex in 0..<trialCount {
            let candidate = greedilyImprove(
                lightlyRefinedGridCandidate(
                    originalElements,
                    canvasSize: size,
                    trialIndex: trialIndex
                ),
                canvasSize: size
            )
            let score = evaluate(candidate, canvasSize: size)
            if score > bestScore {
                bestScore = score
                bestElements = candidate
            }
        }

        applySemanticZOrder(to: &bestElements)
        return apply(elements: bestElements, to: diary, stickers: stickers, layouts: layouts, canvasSize: size)
    }

    private static func makeElements(
        diary: DiaryPage,
        stickers: [StickerPost],
        layouts: [String: StickerLayout],
        canvasSize: CGSize
    ) -> [AutoArrangeElement] {
        var elements: [AutoArrangeElement] = []

        for item in diary.textItems {
            elements.append(AutoArrangeElement(
                id: .text(item.id),
                kind: .text,
                baseSize: estimatedTextSize(item.text),
                center: CGPoint(x: item.x, y: item.y),
                rotation: item.rotation,
                zIndex: item.zIndex,
                scale: item.scale
            ))
        }

        for item in diary.stampItems {
            elements.append(AutoArrangeElement(
                id: .stamp(item.id),
                kind: .stamp,
                baseSize: CGSize(width: 48, height: 48),
                center: CGPoint(x: item.x, y: item.y),
                rotation: item.rotation,
                zIndex: item.zIndex,
                scale: item.scale
            ))
        }

        for sticker in stickers {
            let layout = layouts[sticker.id]
                ?? diary.stickerLayout.first(where: { $0.stickerId == sticker.id })
                ?? sticker.layout
            elements.append(AutoArrangeElement(
                id: .sticker(sticker.id),
                kind: .sticker,
                baseSize: CGSize(
                    width: DiaryCanvasMetrics.stickerBaseSize,
                    height: DiaryCanvasMetrics.stickerBaseSize
                ),
                center: CGPoint(
                    x: canvasSize.width / 2 + layout.x,
                    y: canvasSize.height / 2 + layout.y
                ),
                rotation: layout.rotation,
                zIndex: layout.zIndex,
                scale: layout.scale
            ))
        }

        return elements
    }

    private static func lightlyRefinedGridCandidate(
        _ elements: [AutoArrangeElement],
        canvasSize: CGSize,
        trialIndex: Int
    ) -> [AutoArrangeElement] {
        var candidate = gridSeeded(
            elements,
            canvasSize: canvasSize,
            trialIndex: trialIndex
        )

        let cellSize = approximateCellSize(for: candidate.count, canvasSize: canvasSize, trialIndex: trialIndex)
        let nudge = min(max(min(cellSize.width, cellSize.height) * 0.16, 8), 22)
        var currentScore = evaluate(candidate, canvasSize: canvasSize)

        for index in candidate.indices {
            var bestCenter = candidate[index].center
            var bestScore = currentScore
            let directions = Array(candidateDirections.shuffled().prefix(4)) + [CGVector(dx: 0, dy: 0)]
            for direction in directions {
                var next = candidate
                next[index].center.x += direction.dx * nudge
                next[index].center.y += direction.dy * nudge
                next[index].center = clampedCenter(for: next[index], canvasSize: canvasSize)
                let score = evaluate(next, canvasSize: canvasSize)
                if score > bestScore {
                    bestScore = score
                    bestCenter = next[index].center
                }
            }

            if bestScore > currentScore {
                candidate[index].center = bestCenter
                currentScore = bestScore
            }
        }

        return candidate
    }

    private static func randomized(
        _ elements: [AutoArrangeElement],
        canvasSize: CGSize,
        semanticZOrder: Bool
    ) -> [AutoArrangeElement] {
        let zOrder = elements.indices.shuffled()
        var zIndexes = Array(repeating: 0, count: elements.count)
        for (zIndex, elementIndex) in zOrder.enumerated() {
            zIndexes[elementIndex] = zIndex
        }

        var nextElements = elements.enumerated().map { index, element in
            var next = element
            next.rotation = Double.random(in: -30...30)
            next.zIndex = zIndexes[index]
            next.center = randomCenter(for: next, canvasSize: canvasSize)
            return next
        }
        if semanticZOrder {
            applySemanticZOrder(to: &nextElements)
        }
        return nextElements
    }

    private static func gridSeeded(
        _ elements: [AutoArrangeElement],
        canvasSize: CGSize,
        trialIndex: Int
    ) -> [AutoArrangeElement] {
        let count = max(elements.count, 1)
        let columns = preferredColumnCount(for: count, canvasSize: canvasSize, trialIndex: trialIndex)
        let rows = max(1, Int(ceil(Double(count) / Double(columns))))
        let cellWidth = max((canvasSize.width - safeInset * 2) / CGFloat(columns), 1)
        let cellHeight = max((canvasSize.height - safeInset * 2) / CGFloat(rows), 1)
        let orderedIndices = orderedElementIndices(elements, trialIndex: trialIndex)

        var nextElements = elements
        for (slot, elementIndex) in orderedIndices.enumerated() {
            let column = slot % columns
            let row = slot / columns
            var next = nextElements[elementIndex]
            let jitterX = CGFloat.random(in: (-cellWidth * 0.16)...(cellWidth * 0.16))
            let jitterY = CGFloat.random(in: (-cellHeight * 0.16)...(cellHeight * 0.16))
            next.rotation = Double.random(in: -30...30)
            next.center = CGPoint(
                x: safeInset + cellWidth * (CGFloat(column) + 0.5) + jitterX,
                y: safeInset + cellHeight * (CGFloat(row) + 0.5) + jitterY
            )
            next.center = clampedCenter(for: next, canvasSize: canvasSize)
            next.zIndex = slot
            nextElements[elementIndex] = next
        }
        applySemanticZOrder(to: &nextElements)
        return nextElements
    }

    private static func randomizedScale(for element: AutoArrangeElement) -> Double {
        switch element.kind {
        case .sticker:
            return Double.random(in: 0.82...1.24)
        case .stamp:
            return Double.random(in: 0.88...1.34)
        case .text:
            return Double.random(in: 0.92...1.18)
        }
    }

    private static func preferredColumnCount(for count: Int, canvasSize: CGSize, trialIndex: Int) -> Int {
        guard count > 1 else { return 1 }
        let base: Int
        if count <= 4 {
            base = 2
        } else if count <= 12 {
            base = 3
        } else {
            base = canvasSize.width > canvasSize.height * 0.86 ? 4 : 3
        }

        if trialIndex % 4 == 3, count >= 6 {
            return max(2, base - 1)
        }
        if trialIndex % 5 == 4, count >= 10 {
            return min(base + 1, 4)
        }
        return base
    }

    private static func approximateCellSize(for count: Int, canvasSize: CGSize, trialIndex: Int) -> CGSize {
        let columns = preferredColumnCount(for: max(count, 1), canvasSize: canvasSize, trialIndex: trialIndex)
        let rows = max(1, Int(ceil(Double(max(count, 1)) / Double(columns))))
        return CGSize(
            width: max((canvasSize.width - safeInset * 2) / CGFloat(columns), 1),
            height: max((canvasSize.height - safeInset * 2) / CGFloat(rows), 1)
        )
    }

    private static func orderedElementIndices(_ elements: [AutoArrangeElement], trialIndex: Int) -> [Int] {
        let indices = elements.indices.shuffled()
        guard trialIndex % 2 == 0 else { return indices }
        return indices.sorted { left, right in
            let leftRank = semanticLayerRank(elements[left])
            let rightRank = semanticLayerRank(elements[right])
            if leftRank != rightRank {
                return leftRank < rightRank
            }
            return elements[left].baseSize.width * elements[left].baseSize.height
                > elements[right].baseSize.width * elements[right].baseSize.height
        }
    }

    private static func applySemanticZOrder(to elements: inout [AutoArrangeElement]) {
        let ordered = elements.indices.sorted { left, right in
            let leftRank = semanticLayerRank(elements[left])
            let rightRank = semanticLayerRank(elements[right])
            if leftRank != rightRank {
                return leftRank < rightRank
            }
            return elements[left].zIndex < elements[right].zIndex
        }
        for (zIndex, elementIndex) in ordered.enumerated() {
            elements[elementIndex].zIndex = zIndex
        }
    }

    private static func semanticLayerRank(_ element: AutoArrangeElement) -> Int {
        switch element.kind {
        case .sticker:
            return 0
        case .stamp:
            return 1
        case .text:
            return 2
        }
    }

    private static func greedilyImprove(
        _ elements: [AutoArrangeElement],
        canvasSize: CGSize
    ) -> [AutoArrangeElement] {
        var current = elements
        var currentScore = evaluate(current, canvasSize: canvasSize)

        for step in movementSteps {
            for _ in 0..<maximumPassesPerStep {
                var improvedThisPass = false
                for index in current.indices {
                    var bestCandidate = current
                    var bestScore = currentScore

                    for direction in movementDirections(for: current[index], canvasSize: canvasSize).shuffled() {
                        var candidate = current
                        candidate[index].center.x += direction.dx * step
                        candidate[index].center.y += direction.dy * step
                        candidate[index].center = clampedCenter(for: candidate[index], canvasSize: canvasSize)
                        let score = evaluate(candidate, canvasSize: canvasSize)
                        if score > bestScore {
                            bestScore = score
                            bestCandidate = candidate
                        }
                    }

                    if bestScore > currentScore + 0.001 {
                        current = bestCandidate
                        currentScore = bestScore
                        improvedThisPass = true
                    }
                }
                if !improvedThisPass {
                    if step == movementSteps.first,
                       let shaken = shakenIfImproved(current, canvasSize: canvasSize, currentScore: currentScore) {
                        current = shaken.elements
                        currentScore = shaken.score
                    }
                    break
                }
            }
        }

        return current
    }

    private static func movementDirections(for element: AutoArrangeElement, canvasSize: CGSize) -> [CGVector] {
        let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
        let dx = element.center.x - center.x
        let dy = element.center.y - center.y
        let length = max(hypot(dx, dy), 1)
        let outward = CGVector(dx: dx / length, dy: dy / length)
        let inward = CGVector(dx: -outward.dx, dy: -outward.dy)
        return candidateDirections + [outward, inward]
    }

    private static func shakenIfImproved(
        _ elements: [AutoArrangeElement],
        canvasSize: CGSize,
        currentScore: Double
    ) -> (elements: [AutoArrangeElement], score: Double)? {
        var candidate = elements
        for index in candidate.indices {
            let distance = CGFloat.random(in: 4...14)
            let angle = CGFloat.random(in: 0...(2 * .pi))
            candidate[index].center.x += cos(angle) * distance
            candidate[index].center.y += sin(angle) * distance
            candidate[index].center = clampedCenter(for: candidate[index], canvasSize: canvasSize)
        }
        let score = evaluate(candidate, canvasSize: canvasSize)
        return score > currentScore + 0.001 ? (candidate, score) : nil
    }

    private static func evaluate(
        _ elements: [AutoArrangeElement],
        canvasSize: CGSize
    ) -> Double {
        guard !elements.isEmpty else { return 0 }

        let frames = elements.map(\.frame)
        let canvasRect = CGRect(origin: .zero, size: canvasSize)

        var score = 0.0

        // =========================================================
        // 1. キャンバス外へのはみ出し
        // =========================================================

        for frame in frames {
            let outsideArea = frame.area - frame.intersection(canvasRect).area
            score -= Double(outsideArea) * 2.4
        }

        // =========================================================
        // 2. 要素同士の重なり
        // =========================================================

        for i in elements.indices {
            for j in elements.indices where j > i {
                let overlap = frames[i].intersection(frames[j]).area

                guard overlap > 0 else {
                    continue
                }

                let first = elements[i]
                let second = elements[j]

                let smallerArea = max(
                    min(frames[i].area, frames[j].area),
                    1
                )

                let ratio = Double(overlap / smallerArea)

                let penalty = overlapPenalty(
                    first,
                    second,
                    overlapRatio: ratio
                )

                let frontCoverageMultiplier =
                    frontCoverageMultiplier(first, second)

                score -= Double(overlap)
                    * penalty
                    * frontCoverageMultiplier
            }
        }

        // =========================================================
        // 2.5. 画像ステッカーの中心が前面要素に隠れる配置
        // =========================================================

        for stickerIndex in elements.indices where elements[stickerIndex].kind == .sticker {
            let sticker = elements[stickerIndex]
            for otherIndex in elements.indices where otherIndex != stickerIndex {
                let other = elements[otherIndex]
                guard other.zIndex > sticker.zIndex,
                      frames[otherIndex].contains(sticker.center) else {
                    continue
                }

                let otherOverlap = frames[stickerIndex].intersection(frames[otherIndex]).area
                let stickerArea = max(frames[stickerIndex].area, 1)
                let overlapRatio = Double(otherOverlap / stickerArea)
                score -= 22_000 + overlapRatio * 35_000
            }
        }

        // =========================================================
        // 3. 使用領域
        // =========================================================

        let unionFrame = frames.reduce(frames[0]) {
            $0.union($1)
        }

        let usedRatio = min(
            max(
                unionFrame.area
                    / max(
                        canvasSize.width * canvasSize.height,
                        1
                    ),
                0
            ),
            1
        )

        let targetRatio = min(
            0.62,
            max(
                0.24,
                CGFloat(elements.count) * 0.11
            )
        )

        if usedRatio < targetRatio {
            score -= Double(
                (targetRatio - usedRatio)
                    * canvasSize.width
                    * canvasSize.height
            ) * 0.18
        }

        // =========================================================
        // 4. 中央への偏り
        // =========================================================

        let canvasCenter = CGPoint(
            x: canvasSize.width / 2,
            y: canvasSize.height / 2
        )

        let averageDistance = elements.reduce(0.0) {
            $0 + hypot(
                $1.center.x - canvasCenter.x,
                $1.center.y - canvasCenter.y
            )
        } / Double(elements.count)

        if averageDistance < 48, elements.count > 2 {
            score -= (48 - averageDistance) * 8
        }

        // =========================================================
        // 5. 外側の余白
        // =========================================================

        let outerMargin = min(
            unionFrame.minX,
            unionFrame.minY,
            canvasSize.width - unionFrame.maxX,
            canvasSize.height - unionFrame.maxY
        )

        if outerMargin < safeInset {
            score -= Double(safeInset - outerMargin) * 18
        }

        return score
    }
    private static func overlapPenalty(
        _ first: AutoArrangeElement,
        _ second: AutoArrangeElement,
        overlapRatio: Double
    ) -> Double {

        switch (first.kind, second.kind) {
        case (.sticker, .sticker):
            return 1.6 + overlapRatio * 1.2

        case (.stamp, .stamp):
            return 1.25 + overlapRatio * 0.8

        case (.text, .text):
            return 1.55 + overlapRatio * 1.4

        case (.text, .stamp), (.stamp, .text):
            return 1.3 + overlapRatio

        default:
            if isTextPhotoPair(first, second) {
                return overlapRatio > 0.72
                    ? 0.45 + overlapRatio * 0.9
                    : 0.08
            }
            return 0.95
        }
    }

    private static func frontCoverageMultiplier(_ first: AutoArrangeElement, _ second: AutoArrangeElement) -> Double {
        first.zIndex == second.zIndex ? 1 : 1 + Double(abs(first.zIndex - second.zIndex)) * 0.035
    }

    private static func isTextPhotoPair(_ first: AutoArrangeElement, _ second: AutoArrangeElement) -> Bool {
        (first.kind == .text && second.kind == .sticker) || (first.kind == .sticker && second.kind == .text)
    }

    private static func apply(
        elements: [AutoArrangeElement],
        to diary: DiaryPage,
        stickers: [StickerPost],
        layouts: [String: StickerLayout],
        canvasSize: CGSize
    ) -> DiaryAutoArrangeResult {
        var page = diary
        var nextLayouts = layouts

        for element in elements {
            switch element.id {
            case .text(let id):
                guard let index = page.textItems.firstIndex(where: { $0.id == id }) else { continue }
                page.textItems[index].x = element.center.x
                page.textItems[index].y = element.center.y
                page.textItems[index].rotation = element.rotation
                page.textItems[index].scale = element.scale
                page.textItems[index].zIndex = element.zIndex
            case .stamp(let id):
                guard let index = page.stampItems.firstIndex(where: { $0.id == id }) else { continue }
                page.stampItems[index].x = element.center.x
                page.stampItems[index].y = element.center.y
                page.stampItems[index].rotation = element.rotation
                page.stampItems[index].scale = element.scale
                page.stampItems[index].zIndex = element.zIndex
            case .sticker(let id):
                guard let sticker = stickers.first(where: { $0.id == id }) else { continue }
                var layout = nextLayouts[id]
                    ?? page.stickerLayout.first(where: { $0.stickerId == id })
                    ?? sticker.layout
                layout.x = element.center.x - canvasSize.width / 2
                layout.y = element.center.y - canvasSize.height / 2
                layout.rotation = element.rotation
                layout.scale = element.scale
                layout.zIndex = element.zIndex
                nextLayouts[id] = layout
            }
        }

        return DiaryAutoArrangeResult(diary: page, layouts: nextLayouts)
    }

    private static func estimatedTextSize(_ text: String) -> CGSize {
        let lines = max(text.split(separator: "\n", omittingEmptySubsequences: false).count, 1)
        let longestLine = text.split(separator: "\n", omittingEmptySubsequences: false)
            .map(\.count)
            .max() ?? text.count
        let width = min(max(CGFloat(longestLine) * 14 + 20, 58), 240)
        let height = CGFloat(lines) * 30 + 12
        return CGSize(width: width, height: max(height, 42))
    }

    private static func randomCenter(for element: AutoArrangeElement, canvasSize: CGSize) -> CGPoint {
        let frame = element.frame
        let halfWidth = min(frame.width / 2, max(canvasSize.width / 2 - safeInset, safeInset))
        let halfHeight = min(frame.height / 2, max(canvasSize.height / 2 - safeInset, safeInset))
        let xRange = (safeInset + halfWidth)...max(safeInset + halfWidth, canvasSize.width - safeInset - halfWidth)
        let yRange = (safeInset + halfHeight)...max(safeInset + halfHeight, canvasSize.height - safeInset - halfHeight)
        return CGPoint(x: CGFloat.random(in: xRange), y: CGFloat.random(in: yRange))
    }

    private static func clampedCenter(for element: AutoArrangeElement, canvasSize: CGSize) -> CGPoint {
        let frame = element.frame
        let halfWidth = min(frame.width / 2, max(canvasSize.width / 2 - safeInset, safeInset))
        let halfHeight = min(frame.height / 2, max(canvasSize.height / 2 - safeInset, safeInset))
        return CGPoint(
            x: min(max(element.center.x, safeInset + halfWidth), max(safeInset + halfWidth, canvasSize.width - safeInset - halfWidth)),
            y: min(max(element.center.y, safeInset + halfHeight), max(safeInset + halfHeight, canvasSize.height - safeInset - halfHeight))
        )
    }
}

private extension CGRect {
    var area: CGFloat {
        guard !isNull, width > 0, height > 0 else { return 0 }
        return width * height
    }
}

private struct DiaryLayerActionButton: View {
    let title: String
    let systemImage: String
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .tint(AppColors.mainText)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.42 : 1)
    }
}

private struct DiaryFontPicker: UIViewControllerRepresentable {
    @Binding var selectedFontName: String
    @Binding var isPresented: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(selectedFontName: $selectedFontName, isPresented: $isPresented)
    }

    func makeUIViewController(context: Context) -> UIFontPickerViewController {
        let configuration = UIFontPickerViewController.Configuration()
        configuration.includeFaces = true
        let picker = UIFontPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIFontPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIFontPickerViewControllerDelegate {
        @Binding private var selectedFontName: String
        @Binding private var isPresented: Bool

        init(selectedFontName: Binding<String>, isPresented: Binding<Bool>) {
            _selectedFontName = selectedFontName
            _isPresented = isPresented
        }

        func fontPickerViewControllerDidPickFont(_ viewController: UIFontPickerViewController) {
            guard let descriptor = viewController.selectedFontDescriptor else { return }
            selectedFontName = descriptor.postscriptName
            isPresented = false
        }
    }
}

private struct InteractivePopGestureDisabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Controller {
        Controller()
    }

    func updateUIViewController(_ uiViewController: Controller, context: Context) {
        uiViewController.disableInteractivePopIfNeeded()
    }

    static func dismantleUIViewController(_ uiViewController: Controller, coordinator: Void) {
        uiViewController.restoreInteractivePopIfNeeded()
    }

    final class Controller: UIViewController {
        private weak var popGestureRecognizer: UIGestureRecognizer?
        private var previousIsEnabled: Bool?

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            disableInteractivePopIfNeeded()
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            restoreInteractivePopIfNeeded()
        }

        func disableInteractivePopIfNeeded() {
            guard let recognizer = navigationController?.interactivePopGestureRecognizer else { return }
            if popGestureRecognizer !== recognizer {
                restoreInteractivePopIfNeeded()
                popGestureRecognizer = recognizer
                previousIsEnabled = recognizer.isEnabled
            }
            recognizer.isEnabled = false
        }

        func restoreInteractivePopIfNeeded() {
            guard let recognizer = popGestureRecognizer, let previousIsEnabled else { return }
            recognizer.isEnabled = previousIsEnabled
            popGestureRecognizer = nil
            self.previousIsEnabled = nil
        }
    }
}
