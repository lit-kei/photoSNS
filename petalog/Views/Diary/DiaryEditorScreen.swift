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

struct DiaryEditorScreen: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let group: PetalogGroup
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

    init(group: PetalogGroup) {
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

                editorDock
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
                PetalogMetalBackground()
                InteractivePopGestureDisabler()
                    .frame(width: 0, height: 0)
            }
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
                    }
                }
                .disabled(isSaving || lockMessage != nil || draftDiary == nil)
            }
        }
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
            if let diary = draftDiary ?? viewModel.diary {
                seedLayouts(from: diary)
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

    @ViewBuilder
    private var editorDock: some View {
        VStack(spacing: 9) {
            if let selectedElement, let entry = selectedLayerEntry {
                HStack(spacing: 8) {
                    Label(entry.title, systemImage: entry.systemImage)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    Button {
                        self.selectedElement = nil
                        activeElement = nil
                    } label: {
                        Label("編集を終了", systemImage: "xmark.circle.fill")
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("編集を終了")
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

                selectedDockControls(for: selectedElement)
            } else {
                VStack(spacing: 8) {
                    Text("写真・文字・スタンプをタップして編集")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppColors.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 8) {
                        Button {
                            addText()
                        } label: {
                            Label("文字", systemImage: "text.badge.plus")
                        }

                        Menu {
                            ForEach(["★", "♥", "!!", "→", "✦", "☺"], id: \.self) { stamp in
                                Button(stamp) { addStamp(stamp) }
                            }
                        } label: {
                            Label("スタンプ", systemImage: "star.fill")
                        }

                        Menu {
                            ForEach(ScrapbookBackground.allCases) { background in
                                Button {
                                    draftDiary?.background = background
                                } label: {
                                    Label(background.title, systemImage: background.systemImage)
                                }
                            }
                        } label: {
                            Label("背景", systemImage: "paintpalette.fill")
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(AppColors.mainText)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .controlSize(.large)
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .stroke(AppColors.border, lineWidth: 0.8)
        }
    }

    @ViewBuilder
    private func selectedDockControls(for element: CanvasElementID) -> some View {
        switch element {
        case .text(let textID):
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
                    Label(selectedFontDisplayName, systemImage: "textformat")
                        .lineLimit(1)
                }
                .buttonStyle(.bordered)

                ColorPicker("文字色", selection: selectedTextColorBinding, supportsOpacity: false)
                    .labelsHidden()

                if !(selectedText?.fontName ?? "").isEmpty {
                    Button {
                        updateText(textID) { $0.fontName = "" }
                    } label: {
                        Label("標準フォント", systemImage: "arrow.uturn.backward")
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("システムフォントに戻す")
                }

                Spacer(minLength: 0)
                deleteButton { deleteText(textID) }
            }

        case .stamp(let stampID):
            HStack {
                Spacer()
                deleteButton { deleteStamp(stampID) }
            }

        case .sticker:
            if let selectedSticker,
               selectedSticker.authorId == appState.currentUser?.id {
                HStack {
                    Spacer()
                    deleteButton { Task { await deleteSelectedSticker(selectedSticker) } }
                }
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
            lockMessage = "少し待ってからもう一度開いてください。"
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
        dismiss()
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
                updateText(selectedTextID) { $0.colorHex = UIColor(color).petalogHexString }
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
        DiaryPage(id: "", groupId: group.id, dateKey: Date().petalogDateKey, title: "")
    }

    private var insertionPoint: CGPoint {
        let width = canvasSize.width > 0 ? canvasSize.width : max(UIScreen.main.bounds.width - 40, 320)
        let height = canvasSize.height > 0 ? canvasSize.height : 480
        return CGPoint(x: width / 2, y: height / 2)
    }

    private func addText() {
        let item = DiaryTextItem(
            text: "新しい文字",
            x: insertionPoint.x,
            y: insertionPoint.y,
            zIndex: nextZIndex
        )
        draftDiary?.textItems.append(item)
        activeElement = nil
        selectedElement = .text(item.id)
    }

    private func addStamp(_ symbol: String) {
        let item = DiaryStampItem(
            symbol: symbol,
            x: insertionPoint.x,
            y: insertionPoint.y,
            zIndex: nextZIndex
        )
        draftDiary?.stampItems.append(item)
        activeElement = nil
        selectedElement = .stamp(item.id)
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

    private let logicalHeight: CGFloat = 480

    var body: some View {
        GeometryReader { proxy in
            let logicalWidth = max(proxy.size.width, 1)
            let scale = min(1, max(proxy.size.height, 1) / logicalHeight)

            EditableDiaryCanvas(
                diary: $diary,
                stickers: stickers,
                layouts: $layouts,
                selectedElement: $selectedElement,
                activeElement: $activeElement,
                canvasSize: $canvasSize
            )
            .frame(width: logicalWidth, height: logicalHeight)
            .scaleEffect(scale, anchor: .top)
            .position(x: proxy.size.width / 2, y: logicalHeight / 2)
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
    @State private var lastTapLocation: CGPoint?
    @State private var lastTapDate = Date.distantPast
    @State private var tapCandidates: [CanvasElementID] = []
    @State private var tapCandidateIndex = 0

    var body: some View {
        GeometryReader { proxy in
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
                        .position(x: item.x, y: item.y)
                        .diaryElementFrame(element)
                        .modifier(DiaryElementInteractionModifier(
                            element: element,
                            zIndex: item.zIndex,
                            x: item.x,
                            y: item.y,
                            scale: item.scale,
                            rotation: item.rotation,
                            scaleRange: 0.5...3,
                            selectedElement: $selectedElement,
                            activeElement: $activeElement,
                            updatePosition: { x, y in
                                updateText(item.id) {
                                    $0.x = x
                                    $0.y = y
                                }
                            },
                            updateScale: { scale in updateText(item.id) { $0.scale = scale } },
                            updateRotation: { rotation in updateText(item.id) { $0.rotation = rotation } }
                        ))
                }

                ForEach(diary.stampItems) { item in
                    let element = CanvasElementID.stamp(item.id)
                    Text(item.symbol)
                        .font(.largeTitle.bold())
                        .padding(8)
                        .overlay {
                            if selectedElement == element {
                                Circle().stroke(AppColors.mainText, lineWidth: 1.5)
                            }
                        }
                        .scaleEffect(item.scale)
                        .rotationEffect(.degrees(item.rotation))
                        .position(x: item.x, y: item.y)
                        .diaryElementFrame(element)
                        .modifier(DiaryElementInteractionModifier(
                            element: element,
                            zIndex: item.zIndex,
                            x: item.x,
                            y: item.y,
                            scale: item.scale,
                            rotation: item.rotation,
                            scaleRange: 0.5...3,
                            selectedElement: $selectedElement,
                            activeElement: $activeElement,
                            updatePosition: { x, y in
                                updateStamp(item.id) {
                                    $0.x = x
                                    $0.y = y
                                }
                            },
                            updateScale: { scale in updateStamp(item.id) { $0.scale = scale } },
                            updateRotation: { rotation in updateStamp(item.id) { $0.rotation = rotation } }
                        ))
                }

                ForEach(stickers) { sticker in
                    let layout = layouts[sticker.id] ?? sticker.layout
                    let element = CanvasElementID.sticker(sticker.id)
                    RemoteStickerView(sticker: sticker, size: 118)
                        .overlay {
                            if selectedElement == element {
                                RoundedRectangle(cornerRadius: AppRadius.card)
                                    .stroke(AppColors.mainText, lineWidth: 1.5)
                            }
                        }
                        .scaleEffect(layout.scale)
                        .rotationEffect(.degrees(layout.rotation))
                        .offset(x: layout.x, y: layout.y)
                        .diaryElementFrame(element)
                        .modifier(DiaryElementInteractionModifier(
                            element: element,
                            zIndex: layout.zIndex,
                            x: layout.x,
                            y: layout.y,
                            scale: layout.scale,
                            rotation: layout.rotation,
                            scaleRange: 0.55...1.8,
                            selectedElement: $selectedElement,
                            activeElement: $activeElement,
                            updatePosition: { x, y in
                                updateSticker(sticker) {
                                    $0.x = x
                                    $0.y = y
                                }
                            },
                            updateScale: { scale in updateSticker(sticker) { $0.scale = scale } },
                            updateRotation: { rotation in updateSticker(sticker) { $0.rotation = rotation } }
                        ))
                }

                selectedInteractionProxy

                if tapCandidates.count > 1, let lastTapLocation {
                    Text("\(tapCandidateIndex + 1)/\(tapCandidates.count)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppColors.mainText.opacity(0.82), in: Capsule())
                        .position(indicatorPosition(for: lastTapLocation, in: proxy.size))
                        .zIndex(3_000_000_000_000)
                        .allowsHitTesting(false)
                }
            }
            .coordinateSpace(name: "diaryCanvas")
            .onPreferenceChange(DiaryElementFramePreferenceKey.self) { frames in
                guard frames != elementFrames else { return }
                elementFrames = frames
            }
            .onChange(of: selectedElement) { _, element in
                if element == nil || element.map({ !tapCandidates.contains($0) }) == true {
                    resetTapCycle()
                }
            }
            .simultaneousGesture(
                SpatialTapGesture()
                    .onEnded { value in selectElement(at: value.location) }
            )
            .onAppear {
                if canvasSize != proxy.size {
                    canvasSize = proxy.size
                }
            }
            .onChange(of: proxy.size) { _, size in
                guard canvasSize != size else { return }
                canvasSize = size
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .stroke(AppColors.border, lineWidth: 0.8)
        }
    }

    @ViewBuilder
    private var selectedInteractionProxy: some View {
        if let selectedElement,
           let frame = elementFrames[selectedElement],
           frame.width.isFinite,
           frame.height.isFinite {
            Color.clear
                .frame(width: max(frame.width, 44), height: max(frame.height, 44))
                .contentShape(Rectangle())
                .position(x: frame.midX, y: frame.midY)
                .modifier(interactionModifier(for: selectedElement))
                .zIndex(2_000_000_000_000)
        }
    }

    private func interactionModifier(for element: CanvasElementID) -> DiaryElementInteractionModifier {
        switch element {
        case .text(let id):
            let item = diary.textItems.first(where: { $0.id == id })
            return DiaryElementInteractionModifier(
                element: element,
                zIndex: Int.max,
                x: item?.x ?? 0,
                y: item?.y ?? 0,
                scale: item?.scale ?? 1,
                rotation: item?.rotation ?? 0,
                scaleRange: 0.5...3,
                selectedElement: $selectedElement,
                activeElement: $activeElement,
                raisesWhenActive: true,
                updatePosition: { x, y in updateText(id) { $0.x = x; $0.y = y } },
                updateScale: { scale in updateText(id) { $0.scale = scale } },
                updateRotation: { rotation in updateText(id) { $0.rotation = rotation } }
            )
        case .stamp(let id):
            let item = diary.stampItems.first(where: { $0.id == id })
            return DiaryElementInteractionModifier(
                element: element,
                zIndex: Int.max,
                x: item?.x ?? 0,
                y: item?.y ?? 0,
                scale: item?.scale ?? 1,
                rotation: item?.rotation ?? 0,
                scaleRange: 0.5...3,
                selectedElement: $selectedElement,
                activeElement: $activeElement,
                raisesWhenActive: true,
                updatePosition: { x, y in updateStamp(id) { $0.x = x; $0.y = y } },
                updateScale: { scale in updateStamp(id) { $0.scale = scale } },
                updateRotation: { rotation in updateStamp(id) { $0.rotation = rotation } }
            )
        case .sticker(let id):
            let sticker = stickers.first(where: { $0.id == id })
            let layout = sticker.map { layouts[id] ?? $0.layout }
            return DiaryElementInteractionModifier(
                element: element,
                zIndex: Int.max,
                x: layout?.x ?? 0,
                y: layout?.y ?? 0,
                scale: layout?.scale ?? 1,
                rotation: layout?.rotation ?? 0,
                scaleRange: 0.55...1.8,
                selectedElement: $selectedElement,
                activeElement: $activeElement,
                raisesWhenActive: true,
                updatePosition: { x, y in
                    guard let sticker else { return }
                    updateSticker(sticker) { $0.x = x; $0.y = y }
                },
                updateScale: { scale in
                    guard let sticker else { return }
                    updateSticker(sticker) { $0.scale = scale }
                },
                updateRotation: { rotation in
                    guard let sticker else { return }
                    updateSticker(sticker) { $0.rotation = rotation }
                }
            )
        }
    }

    private func selectElement(at location: CGPoint) {
        let candidates = diaryLayerEntries(diary: diary, stickers: stickers, layouts: layouts)
            .map(\.element)
            .filter { elementFrames[$0]?.insetBy(dx: -8, dy: -8).contains(location) == true }

        guard !candidates.isEmpty else {
            selectedElement = nil
            activeElement = nil
            resetTapCycle(at: location)
            return
        }

        let isRepeatedTap = tapCandidates == candidates
            && Date().timeIntervalSince(lastTapDate) < 1.2
            && lastTapLocation.map { hypot($0.x - location.x, $0.y - location.y) <= 22 } == true

        tapCandidateIndex = isRepeatedTap ? (tapCandidateIndex + 1) % candidates.count : 0
        tapCandidates = candidates
        lastTapLocation = location
        lastTapDate = Date()
        selectedElement = candidates[tapCandidateIndex]
        activeElement = nil
    }

    private func resetTapCycle(at location: CGPoint? = nil) {
        tapCandidates = []
        tapCandidateIndex = 0
        lastTapLocation = location
        lastTapDate = .distantPast
    }

    private func indicatorPosition(for location: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(
            x: min(max(location.x + 24, 30), max(size.width - 30, 30)),
            y: min(max(location.y - 28, 18), max(size.height - 18, 18))
        )
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

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .opacity(isDimmed ? 0.25 : 1)
            .zIndex(displayZIndex)
            .allowsHitTesting(!isDimmed)
            .animation(.easeOut(duration: 0.15), value: isDimmed)
            .highPriorityGesture(dragGesture)
            .simultaneousGesture(scaleGesture)
            .simultaneousGesture(rotationGesture)
    }

    private var displayZIndex: Double {
        if isActive && raisesWhenActive { return 1_000_000_000_000 }
        if isDimmed { return -1_000_000_000_000 + Double(zIndex) }
        return Double(zIndex)
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                beginInteraction(.drag)
                let origin = dragOrigin ?? CGSize(width: x, height: y)
                if dragOrigin == nil { dragOrigin = origin }
                updatePosition(origin.width + value.translation.width, origin.height + value.translation.height)
            }
            .onEnded { _ in
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
        selectedElement = element
        activeElement = element
        switch kind {
        case .drag: isDragging = true
        case .scale: isScaling = true
        case .rotation: isRotating = true
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
