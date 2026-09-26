import PhotosUI
import SwiftUI
import UIKit

enum CanvasElementID: Hashable, Identifiable {
    case sticker(String)
    case text(String)
    case stamp(String)
    case design(String)

    var id: String {
        switch self {
        case .sticker(let id): "sticker:\(id)"
        case .text(let id): "text:\(id)"
        case .stamp(let id): "stamp:\(id)"
        case .design(let id): "design:\(id)"
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
    case design = "フィルター"
    case drawing = "手書き"
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
    @State private var originalDiary: DiaryPage?
    @State private var originalLayouts: [String: StickerLayout] = [:]
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
    @State private var selectedBackgroundPhotoItem: PhotosPickerItem?
    @State private var isShowingBackgroundPhotoPicker = false
    @State private var backgroundImageData: Data?
    @State private var isShowingBackgroundCamera = false
    @State private var backgroundImageError: String?
    @State private var isShowingDiscardAlert = false
    @State private var drawingColor = Color(
        uiColor: UIColor(hex: DiaryDrawingStroke.defaultColorHex) ?? UIColor(AppColors.mainText)
    )
    @State private var drawingLineWidth: Double = 2
    @State private var drawingZoomScale: Double = 1
    @State private var drawingPanOffset: CGSize = .zero
    @State private var isDrawingPanMode = false


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
                    canvasSize: $canvasSize,
                    backgroundImageData: backgroundImageData,
                    isDrawingEnabled: isDrawingEnabled,
                    drawingZoomScale: $drawingZoomScale,
                    drawingPanOffset: $drawingPanOffset,
                    isDrawingPanMode: $isDrawingPanMode,
                    drawingColorHex: UIColor(drawingColor).petankoHexString,
                    drawingLineWidth: drawingLineWidth
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.bottom, editorBottomSheetHeight)
                .animation(.easeInOut(duration: 0.2), value: editorBottomSheetHeight)
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
                    requestDismiss()
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
            if originalDiary == nil {
                originalDiary = diary
                originalLayouts = localLayouts
            }
            Task { await lockIfPossible() }
        }
        .onChange(of: viewModel.stickers) { _, _ in
            if let diary = draftDiary ?? viewModel.diary {
                seedLayouts(from: diary)
                if originalDiary != nil, originalLayouts.isEmpty, !localLayouts.isEmpty {
                    originalLayouts = localLayouts
                }
            }
        }
        .onChange(of: selectedElement) { _, element in
            switch element {
            case .text:
                selectedEditorTab = .text
            case .stamp:
                selectedEditorTab = .stamp
            case .design:
                selectedEditorTab = .design
            case .sticker, nil:
                break
            }
        }
        .onChange(of: selectedBackgroundPhotoItem) { _, item in
            guard let item else { return }
            Task {
                do {
                    guard let data = try await item.loadTransferable(type: Data.self) else {
                        throw PetankoError.message("選択した写真を読み込めませんでした。")
                    }
                    applyBackgroundImageData(data)
                } catch {
                    backgroundImageError = error.localizedDescription
                    selectedBackgroundPhotoItem = nil
                }
            }
        }
        .photosPicker(
            isPresented: $isShowingBackgroundPhotoPicker,
            selection: $selectedBackgroundPhotoItem,
            matching: .images,
            photoLibrary: .shared()
        )
        .sheet(isPresented: $isShowingFontPicker) {
            DiaryFontPicker(
                selectedFontName: selectedFontNameBinding,
                isPresented: $isShowingFontPicker
            )
                .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $isShowingBackgroundCamera) {
            DiaryBackgroundCameraPicker(isPresented: $isShowingBackgroundCamera) { image in
                guard let data = image.jpegData(compressionQuality: 0.92) else {
                    backgroundImageError = "撮影した写真を読み込めませんでした。"
                    return
                }
                applyBackgroundImageData(data)
            }
            .ignoresSafeArea()
        }
        .alert("背景写真", isPresented: backgroundImageErrorPresented) {
            Button("閉じる", role: .cancel) {
                backgroundImageError = nil
            }
        } message: {
            Text(backgroundImageError ?? "写真を読み込めませんでした。")
        }
        .alert("変更を破棄しますか？", isPresented: $isShowingDiscardAlert) {
            Button("キャンセル", role: .cancel) {}
            Button("破棄", role: .destructive) {
                dismiss()
            }
        } message: {
            Text("編集した内容は保存されません。")
        }
    }

    private var isStickerSelected: Bool {
        if case .sticker = selectedElement {
            return true
        }
        return false
    }

    private var hasUnsavedChanges: Bool {
        guard let originalDiary,
              let currentDiary = comparableDraftDiary(),
              backgroundImageData == nil else {
            return backgroundImageData != nil
        }

        var original = originalDiary
        original.stickerLayout = comparableLayouts(originalLayouts)
        return currentDiary != original
    }

    private func requestDismiss() {
        if hasUnsavedChanges {
            isShowingDiscardAlert = true
        } else {
            dismiss()
        }
    }

    private func comparableDraftDiary() -> DiaryPage? {
        guard var page = draftDiary else { return nil }
        inputBuffer.apply(to: &page)
        page.stickerLayout = comparableLayouts(localLayouts)
        return page
    }

    private func comparableLayouts(_ layouts: [String: StickerLayout]) -> [StickerLayout] {
        let stickerIDs = Set(viewModel.stickers.map(\.id))
        return layouts.values
            .filter { stickerIDs.contains($0.stickerId) }
            .map(DiaryCanvasMetrics.sanitizedStickerLayout)
            .sorted { $0.zIndex < $1.zIndex }
    }

    private var isDesignSelected: Bool {
        if case .design = selectedElement {
            return true
        }
        return false
    }


    @ViewBuilder
    private var editorBottomSheet: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                if case .text(let textID) = selectedElement {
                    textEditingControls(textID: textID)
                    selectedObjectSummary
                } else if case .stamp = selectedElement {
                    editorTabContent
                    selectedObjectSummary
                } else if case .design = selectedElement {
                    editorTabContent
                    selectedObjectSummary
                } else {
                    if selectedElement != nil {
                        selectedObjectSummary
                    }

                    if !isStickerSelected {
                        editorTabContent
                    }
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
                            if tab == .drawing {
                                selectedElement = nil
                                activeElement = nil
                            }
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
                        Label("文字を追加", systemImage: "text.badge.plus")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(AppColors.mainText)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(
                                AppColors.accentPink,
                                in: RoundedRectangle(cornerRadius: AppRadius.chip, style: .continuous)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

        case .stamp:
            VStack(alignment: .leading, spacing: 9) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(["★", "♥", "!!", "→", "✦", "♪"], id: \.self) { stamp in
                            let isSelectedStampSymbol = selectedStamp?.symbol == stamp
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
                            .tint(isSelectedStampSymbol ? AppColors.burntOrange : AppColors.mainText)
                        }
                    }
                }

                if case .stamp(let stampID) = selectedElement {
                    HStack(spacing: 10) {
                        ColorPicker("カラー", selection: selectedStampColorBinding, supportsOpacity: false)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppColors.mainText)
                            .lineLimit(1)
                            .padding(.horizontal, 9)
                            .frame(height: 38)
                            .background(AppColors.accentPink.opacity(0.16), in: Capsule())
                            .overlay {
                                Capsule()
                                    .stroke(AppColors.accentPink.opacity(0.45), lineWidth: 1)
                            }
                            .fixedSize(horizontal: true, vertical: false)

                        Menu {
                            ForEach(DiaryStampDesign.allCases) { design in
                                Button {
                                    updateStamp(stampID) { $0.design = design }
                                } label: {
                                    Label(
                                        design.title,
                                        systemImage: stampDesign(for: stampID) == design
                                            ? "checkmark.circle.fill"
                                            : design.systemImage
                                    )
                                }
                            }
                        } label: {
                            Label("デザイン", systemImage: "wand.and.sparkles")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppColors.mainText)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .padding(.horizontal, 9)
                                .frame(height: 38)
                                .background(AppColors.accentPink.opacity(0.16), in: Capsule())
                                .overlay {
                                    Capsule()
                                        .stroke(AppColors.accentPink.opacity(0.45), lineWidth: 1)
                                }
                        }
                        .accessibilityValue(stampDesign(for: stampID).title)

                        Spacer(minLength: 0)

                        Button(role: .destructive) {
                            deleteStamp(stampID)
                        } label: {
                            Label("削除", systemImage: "trash")
                                .font(.caption.weight(.bold))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .padding(.horizontal, 9)
                                .frame(height: 38)
                                .background(
                                    AppColors.destructiveRed.opacity(0.09),
                                    in: Capsule()
                                )
                                .overlay {
                                    Capsule()
                                        .stroke(AppColors.destructiveRed.opacity(0.30), lineWidth: 1)
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

        case .design:
            VStack(alignment: .leading, spacing: 10) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(DiaryDesignEffect.allCases) { effect in
                            Button {
                                if case .design(let designID) = selectedElement {
                                    updateDesign(designID) {
                                        $0.effect = effect
                                        $0.opacity = defaultOpacity(for: effect)
                                    }
                                } else {
                                    addDesign(effect)
                                }
                            } label: {
                                Label(effect.title, systemImage: effect.systemImage)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(AppColors.mainText)
                                    .padding(.horizontal, 12)
                                    .frame(height: 42)
                                    .background {
                                        RoundedRectangle(cornerRadius: AppRadius.chip, style: .continuous)
                                            .fill(
                                                selectedDesign?.effect == effect
                                                    ? AppColors.accentPink.opacity(0.28)
                                                    : AppColors.elevatedSurface
                                            )
                                    }
                                    .overlay {
                                        RoundedRectangle(cornerRadius: AppRadius.chip, style: .continuous)
                                            .stroke(
                                                selectedDesign?.effect == effect
                                                    ? AppColors.accentPink
                                                    : AppColors.border,
                                                lineWidth: 1
                                            )
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if case .design(let designID) = selectedElement {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            if selectedDesign?.effect == .translucent {
                                ColorPicker("カラー", selection: selectedDesignColorBinding, supportsOpacity: false)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(AppColors.mainText)
                                    .lineLimit(1)
                                    .padding(.horizontal, 9)
                                    .frame(height: 36)
                                    .background(AppColors.accentPink.opacity(0.16), in: Capsule())
                            }

                            Menu {
                                ForEach(DiaryDesignShape.allCases) { shape in
                                    Button {
                                        updateDesign(designID) { $0.shape = shape }
                                    } label: {
                                        Label(
                                            shape.title,
                                            systemImage: selectedDesign?.shape == shape
                                                ? "checkmark"
                                                : shape.systemImage
                                        )
                                    }
                                }
                            } label: {
                                Label(
                                    selectedDesign?.shape.title ?? "形",
                                    systemImage: selectedDesign?.shape.systemImage ?? "square"
                                )
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppColors.mainText)
                                .padding(.horizontal, 9)
                                .frame(height: 36)
                                .background(AppColors.accentPink.opacity(0.16), in: Capsule())
                            }

                            HStack(spacing: 5) {
                                Image(systemName: "arrow.left.and.right")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(AppColors.secondaryText)

                                Slider(value: selectedDesignWidthBinding, in: 44...320)
                                    .tint(AppColors.accentPink)
                                    .frame(width: 72)
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("横幅")

                            HStack(spacing: 5) {
                                Image(systemName: "arrow.up.and.down")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(AppColors.secondaryText)

                                Slider(value: selectedDesignHeightBinding, in: 44...400)
                                    .tint(AppColors.accentPink)
                                    .frame(width: 72)
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("高さ")

                            if selectedDesign?.effect != .eightBit {
                                HStack(spacing: 6) {
                                    Text("透明度")
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(AppColors.mainText)

                                    Slider(value: selectedDesignOpacityBinding, in: 0.08...1)
                                        .tint(AppColors.accentPink)
                                        .frame(width: 82)
                                }
                            } else {
                                Label("枠内を低画質化", systemImage: "square.grid.3x3.fill")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(AppColors.secondaryText)
                            }

                            Button {
                                selectedDesignHasBorderBinding.wrappedValue.toggle()
                            } label: {
                                Label(
                                    "縁",
                                    systemImage: selectedDesign?.hasBorder == true
                                        ? "checkmark.square.fill"
                                        : "square"
                                )
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppColors.mainText)
                                .padding(.horizontal, 9)
                                .frame(height: 36)
                                .background(AppColors.accentPink.opacity(0.16), in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .accessibilityValue(selectedDesign?.hasBorder == true ? "オン" : "オフ")

                            if selectedDesign?.hasBorder == true {
                                ColorPicker(
                                    "縁色",
                                    selection: selectedDesignBorderColorBinding,
                                    supportsOpacity: false
                                )
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppColors.mainText)
                                .lineLimit(1)
                                .padding(.horizontal, 9)
                                .frame(height: 36)
                                .background(AppColors.accentPink.opacity(0.16), in: Capsule())
                            }

                            Button(role: .destructive) {
                                deleteDesign(designID)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.subheadline.weight(.bold))
                                    .frame(width: 36, height: 36)
                                    .background(AppColors.destructiveRed.opacity(0.09), in: Circle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("フィルターを削除")
                        }
                    }
                }
            }

        case .drawing:
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    ColorPicker("カラー", selection: $drawingColor, supportsOpacity: false)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppColors.mainText)
                        .padding(.horizontal, 10)
                        .frame(height: 38)
                        .background(AppColors.accentPink.opacity(0.16), in: Capsule())

                    HStack(spacing: 7) {
                        Image(systemName: "scribble.variable")
                            .foregroundStyle(AppColors.accentPink)

                        Slider(value: $drawingLineWidth, in: 0.5...12, step: 0.5)
                            .tint(AppColors.accentPink)
                            .frame(minWidth: 86)

                        Text(drawingLineWidth.formatted(.number.precision(.fractionLength(drawingLineWidth < 2 ? 1 : 0))))
                            .font(.caption.monospacedDigit().weight(.bold))
                            .foregroundStyle(AppColors.secondaryText)
                            .frame(width: 22)
                    }

                    Button {
                        undoLastDrawingStroke()
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(AppColors.mainText)
                    .background(AppColors.accentPink.opacity(0.14), in: Circle())
                    .disabled(draftDiary?.drawingStrokes.isEmpty != false)
                    .opacity(draftDiary?.drawingStrokes.isEmpty == false ? 1 : 0.4)
                    .accessibilityLabel("最後の線を取り消す")

                    Button(role: .destructive) {
                        clearDrawingStrokes()
                    } label: {
                        Image(systemName: "trash")
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(AppColors.destructiveRed)
                    .background(AppColors.destructiveRed.opacity(0.09), in: Circle())
                    .disabled(draftDiary?.drawingStrokes.isEmpty != false)
                    .opacity(draftDiary?.drawingStrokes.isEmpty == false ? 1 : 0.4)
                    .accessibilityLabel("手書きをすべて削除")
                }

                HStack(spacing: 12) {
                    Button {
                        drawingZoomScale = max(1, drawingZoomScale - 0.25)
                    } label: {
                        Image(systemName: "minus.magnifyingglass")
                            .frame(width: 34, height: 32)
                    }
                    .buttonStyle(.plain)
                    .disabled(drawingZoomScale <= 1)
                    .opacity(drawingZoomScale <= 1 ? 0.4 : 1)
                    .accessibilityLabel("縮小")

                    Slider(value: $drawingZoomScale, in: 1...3, step: 0.05)
                        .tint(AppColors.accentPink)

                    Text("\(Int((drawingZoomScale * 100).rounded()))%")
                        .font(.caption.monospacedDigit().weight(.bold))
                        .foregroundStyle(AppColors.secondaryText)
                        .frame(width: 42)

                    Button {
                        drawingZoomScale = min(3, drawingZoomScale + 0.25)
                    } label: {
                        Image(systemName: "plus.magnifyingglass")
                            .frame(width: 34, height: 32)
                    }
                    .buttonStyle(.plain)
                    .disabled(drawingZoomScale >= 3)
                    .opacity(drawingZoomScale >= 3 ? 0.4 : 1)
                    .accessibilityLabel("拡大")

                    Button {
                        isDrawingPanMode.toggle()
                    } label: {
                        Image(systemName: isDrawingPanMode ? "pencil.tip" : "hand.draw.fill")
                            .foregroundStyle(isDrawingPanMode ? .white : AppColors.mainText)
                            .frame(width: 34, height: 32)
                            .background(
                                isDrawingPanMode ? AppColors.accentPink : AppColors.accentPink.opacity(0.14),
                                in: Circle()
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(drawingZoomScale <= 1)
                    .opacity(drawingZoomScale <= 1 ? 0.4 : 1)
                    .accessibilityLabel(isDrawingPanMode ? "手書きに戻る" : "画面を移動")
                }
                .padding(.horizontal, 8)
                .background(AppColors.accentPink.opacity(0.10), in: Capsule())
            }

        case .background:
            VStack(alignment: .leading, spacing: 9) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Menu {
                            Button("カメラ") {
                                openBackgroundCamera()
                            }
                            Button("写真フォルダ") {
                                isShowingBackgroundPhotoPicker = true
                            }
                        } label: {
                            Text("オリジナル")
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 14)
                                .frame(height: 42)
                        }
                        .buttonStyle(.bordered)
                        .tint(isUsingCustomBackground ? AppColors.burntOrange : AppColors.mainText)

                        ForEach(ScrapbookBackground.allCases) { background in
                            backgroundOptionButton(
                                title: background.title,
                                isSelected: !isUsingCustomBackground && draftDiary?.background == background
                            ) {
                                selectPresetBackground(background)
                            }
                        }
                    }
                }
            }
        }
    }

    private var selectedObjectSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Label("レイヤー", systemImage: "square.3.layers.3d")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppColors.mainText)

                Spacer(minLength: 4)

                Button {
                    selectedElement = nil
                    activeElement = nil
                } label: {
                    Text("完了")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppColors.mainText)
                        .padding(.horizontal, 13)
                        .frame(height: 32)
                        .background(AppColors.accentPink, in: Capsule())
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {
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
        .padding(12)
        .background(
            AppColors.accentPink.opacity(0.10),
            in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .stroke(AppColors.accentPink.opacity(0.38), lineWidth: 1)
        }
    }

    private func textEditingControls(textID: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("文字", systemImage: "textformat")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppColors.mainText)

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
                    Text("Aa")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppColors.mainText)
                        .lineLimit(1)
                        .frame(width: 48, height: 38)
                        .background(AppColors.accentPink.opacity(0.16), in: Capsule())
                        .overlay {
                            Capsule()
                                .stroke(AppColors.accentPink.opacity(0.45), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("フォント：\(selectedFontDisplayName)")

                ColorPicker("カラー", selection: selectedTextColorBinding, supportsOpacity: false)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColors.mainText)
                    .lineLimit(1)
                    .padding(.horizontal, 9)
                    .frame(height: 38)
                    .background(AppColors.accentPink.opacity(0.16), in: Capsule())
                    .overlay {
                        Capsule()
                            .stroke(AppColors.accentPink.opacity(0.45), lineWidth: 1)
                    }

                if !(selectedText?.fontName ?? "").isEmpty {
                    Button {
                        updateText(textID) { $0.fontName = "" }
                    } label: {
                        Text("標準")
                            .font(.caption.weight(.bold))
                            .lineLimit(1)
                    }
                    .buttonStyle(.bordered)
                    .tint(AppColors.accentPink)
                    .accessibilityLabel("システムフォントに戻す")
                }

                Spacer(minLength: 0)

                Button(role: .destructive) {
                    deleteText(textID)
                } label: {
                    Label("削除", systemImage: "trash")
                        .font(.caption.weight(.bold))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.horizontal, 9)
                        .frame(height: 38)
                        .background(
                            AppColors.destructiveRed.opacity(0.09),
                            in: Capsule()
                        )
                        .overlay {
                            Capsule()
                                .stroke(AppColors.destructiveRed.opacity(0.30), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(
            AppColors.elevatedSurface,
            in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .stroke(AppColors.accentPink.opacity(0.32), lineWidth: 1)
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
            let layout = diary.stickerLayout.first(where: { $0.stickerId == sticker.id }) ?? sticker.layout
            next[sticker.id] = DiaryCanvasMetrics.sanitizedStickerLayout(layout)
        }
        for stickerID in Array(next.keys) {
            if let layout = next[stickerID] {
                next[stickerID] = DiaryCanvasMetrics.sanitizedStickerLayout(layout)
            }
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
        layouts = layouts.mapValues(DiaryCanvasMetrics.sanitizedStickerLayout)
        let order = diaryLayerEntries(diary: page, stickers: viewModel.stickers, layouts: layouts).map(\.element)
        applyDiaryLayerOrder(order, diary: &page, stickers: viewModel.stickers, layouts: &layouts)
        let stickerIDs = Set(viewModel.stickers.map(\.id))
        page.stickerLayout = layouts.values
            .filter { stickerIDs.contains($0.stickerId) }
            .map(DiaryCanvasMetrics.sanitizedStickerLayout)
            .sorted { $0.zIndex < $1.zIndex }
        draftDiary = page
        localLayouts = layouts
        guard let savedPage = await viewModel.saveDiary(page, backgroundImageData: backgroundImageData) else {
            isSaving = false
            backgroundImageError = viewModel.errorMessage ?? "変更を保存できませんでした。もう一度お試しください。"
            return
        }
        draftDiary = savedPage
        backgroundImageData = nil
        selectedBackgroundPhotoItem = nil
        isSaving = false
        stopLockHeartbeat()
        dismiss()
    }

    private var isDrawingEnabled: Bool {
        selectedEditorTab == .drawing && selectedElement == nil
    }

    private func undoLastDrawingStroke() {
        guard draftDiary?.drawingStrokes.isEmpty == false else { return }
        draftDiary?.drawingStrokes.removeLast()
    }

    private func clearDrawingStrokes() {
        guard draftDiary?.drawingStrokes.isEmpty == false else { return }
        draftDiary?.drawingStrokes.removeAll()
    }

    private var isUsingCustomBackground: Bool {
        backgroundImageData != nil || draftDiary?.backgroundImageURL?.isEmpty == false
    }

    private var backgroundImageErrorPresented: Binding<Bool> {
        Binding(
            get: { backgroundImageError != nil },
            set: { isPresented in
                if !isPresented { backgroundImageError = nil }
            }
        )
    }

    private func backgroundOptionButton(
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .frame(height: 42)
        }
        .buttonStyle(.bordered)
        .tint(isSelected ? AppColors.burntOrange : AppColors.mainText)
    }

    private func openBackgroundCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            backgroundImageError = "この端末ではカメラを使用できません。"
            return
        }
        isShowingBackgroundCamera = true
    }

    private func applyBackgroundImageData(_ data: Data) {
        let optimizedData = data.petankoOptimizedJPEG(
            maxDimension: 1_800,
            quality: 0.82,
            maximumBytes: 1_500_000
        )
        guard UIImage(data: optimizedData) != nil else {
            backgroundImageError = "選択した写真を読み込めませんでした。"
            selectedBackgroundPhotoItem = nil
            return
        }
        backgroundImageData = optimizedData
        selectedBackgroundPhotoItem = nil
        selectedElement = nil
        activeElement = nil
    }

    private func selectPresetBackground(_ background: ScrapbookBackground) {
        draftDiary?.background = background
        draftDiary?.backgroundImageURL = nil
        backgroundImageData = nil
        selectedBackgroundPhotoItem = nil
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

    private var selectedDesign: DiaryDesignItem? {
        guard case .design(let id) = selectedElement else { return nil }
        return draftDiary?.designItems.first { $0.id == id }
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

    private var selectedDesignColorBinding: Binding<Color> {
        Binding(
            get: {
                Color(uiColor: UIColor(hex: selectedDesign?.colorHex ?? DiaryDesignItem.defaultColorHex) ?? UIColor.systemPink)
            },
            set: { color in
                guard case .design(let id) = selectedElement else { return }
                updateDesign(id) { $0.colorHex = UIColor(color).petankoHexString }
            }
        )
    }

    private var selectedDesignOpacityBinding: Binding<Double> {
        Binding(
            get: { selectedDesign?.opacity ?? 0.48 },
            set: { value in
                guard case .design(let id) = selectedElement else { return }
                updateDesign(id) { $0.opacity = value }
            }
        )
    }

    private var selectedDesignHasBorderBinding: Binding<Bool> {
        Binding(
            get: { selectedDesign?.hasBorder ?? false },
            set: { value in
                guard case .design(let id) = selectedElement else { return }
                updateDesign(id) { $0.hasBorder = value }
            }
        )
    }

    private var selectedDesignWidthBinding: Binding<Double> {
        Binding(
            get: { selectedDesign?.width ?? 140 },
            set: { value in
                guard case .design(let id) = selectedElement else { return }
                updateDesign(id) { $0.width = value }
            }
        )
    }

    private var selectedDesignHeightBinding: Binding<Double> {
        Binding(
            get: { selectedDesign?.height ?? 140 },
            set: { value in
                guard case .design(let id) = selectedElement else { return }
                updateDesign(id) { $0.height = value }
            }
        )
    }

    private var selectedDesignBorderColorBinding: Binding<Color> {
        Binding(
            get: {
                Color(
                    uiColor: UIColor(
                        hex: selectedDesign?.borderColorHex ?? DiaryDesignItem.defaultBorderColorHex
                    ) ?? .white
                )
            },
            set: { color in
                guard case .design(let id) = selectedElement else { return }
                updateDesign(id) { $0.borderColorHex = UIColor(color).petankoHexString }
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

    private func addDesign(_ effect: DiaryDesignEffect) {
        let item = DiaryDesignItem(
            effect: effect,
            colorHex: randomDiaryAccentColorHex,
            opacity: defaultOpacity(for: effect),
            x: insertionPoint.x,
            y: insertionPoint.y,
            width: 140,
            height: 140,
            zIndex: nextZIndex
        )
        draftDiary?.designItems.append(item)
        activeElement = nil
        selectedElement = .design(item.id)
    }

    private func defaultOpacity(for effect: DiaryDesignEffect) -> Double {
        switch effect {
        case .invert, .tint:
            return 1
        case .translucent:
            return 0.48
        case .eightBit:
            return 1
        }
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

    private func stampDesign(for id: String) -> DiaryStampDesign {
        draftDiary?.stampItems.first(where: { $0.id == id })?.design ?? .normal
    }

    private func deleteStamp(_ id: String) {
        draftDiary?.stampItems.removeAll { $0.id == id }
        activeElement = nil
        selectedElement = nil
    }

    private func updateDesign(_ id: String, mutate: (inout DiaryDesignItem) -> Void) {
        guard var page = draftDiary,
              let index = page.designItems.firstIndex(where: { $0.id == id }) else { return }
        mutate(&page.designItems[index])
        draftDiary = page
    }

    private func deleteDesign(_ id: String) {
        draftDiary?.designItems.removeAll { $0.id == id }
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
    let backgroundImageData: Data?
    let isDrawingEnabled: Bool
    @Binding var drawingZoomScale: Double
    @Binding var drawingPanOffset: CGSize
    @Binding var isDrawingPanMode: Bool
    let drawingColorHex: String
    let drawingLineWidth: Double

    @GestureState private var liveMagnification: CGFloat = 1
    @State private var panStartOffset: CGSize?

    var body: some View {
        GeometryReader { proxy in
            let logicalSize = DiaryCanvasMetrics.logicalSize
            let scale = min(
                max(proxy.size.width, 1) / logicalSize.width,
                max(proxy.size.height, 1) / logicalSize.height
            )
            let zoomScale: CGFloat = isDrawingEnabled
                ? min(3, max(1, CGFloat(drawingZoomScale) * liveMagnification))
                : 1

            EditableDiaryCanvas(
                diary: $diary,
                stickers: stickers,
                layouts: $layouts,
                selectedElement: $selectedElement,
                activeElement: $activeElement,
                canvasSize: $canvasSize,
                backgroundImageData: backgroundImageData,
                isDrawingEnabled: isDrawingEnabled,
                isDrawingPanEnabled: isDrawingPanMode,
                drawingColorHex: drawingColorHex,
                drawingLineWidth: drawingLineWidth
            )
            .frame(width: logicalSize.width, height: logicalSize.height)
            .scaleEffect(scale * zoomScale, anchor: .center)
            .position(
                x: proxy.size.width / 2 + drawingPanOffset.width,
                y: logicalSize.height * scale / 2 + drawingPanOffset.height
            )
            .simultaneousGesture(
                MagnificationGesture()
                    .updating($liveMagnification) { value, state, _ in
                        guard isDrawingEnabled else { return }
                        state = value
                    }
                    .onEnded { value in
                        guard isDrawingEnabled else { return }
                        drawingZoomScale = min(3, max(1, drawingZoomScale * Double(value)))
                    }
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        guard isDrawingEnabled, isDrawingPanMode, drawingZoomScale > 1 else { return }
                        let start = panStartOffset ?? drawingPanOffset
                        if panStartOffset == nil {
                            panStartOffset = start
                        }
                        drawingPanOffset = clampedPanOffset(
                            CGSize(
                                width: start.width + value.translation.width,
                                height: start.height + value.translation.height
                            ),
                            viewportSize: proxy.size,
                            baseScale: scale,
                            zoomScale: zoomScale
                        )
                    }
                    .onEnded { _ in
                        panStartOffset = nil
                    }
            )
            .onChange(of: drawingZoomScale) { _, newValue in
                if newValue <= 1 {
                    drawingPanOffset = .zero
                    isDrawingPanMode = false
                } else {
                    drawingPanOffset = clampedPanOffset(
                        drawingPanOffset,
                        viewportSize: proxy.size,
                        baseScale: scale,
                        zoomScale: CGFloat(newValue)
                    )
                }
            }
            .onChange(of: isDrawingEnabled) { _, enabled in
                if !enabled {
                    drawingZoomScale = 1
                    drawingPanOffset = .zero
                    isDrawingPanMode = false
                }
            }
        }
        .clipped()
    }

    private func clampedPanOffset(
        _ proposed: CGSize,
        viewportSize: CGSize,
        baseScale: CGFloat,
        zoomScale: CGFloat
    ) -> CGSize {
        let contentSize = CGSize(
            width: DiaryCanvasMetrics.logicalSize.width * baseScale * zoomScale,
            height: DiaryCanvasMetrics.logicalSize.height * baseScale * zoomScale
        )
        let maxX = max(0, (contentSize.width - viewportSize.width) / 2)
        let maxY = max(0, (contentSize.height - viewportSize.height) / 2)
        return CGSize(
            width: min(maxX, max(-maxX, proposed.width)),
            height: min(maxY, max(-maxY, proposed.height))
        )
    }
}

private struct DiaryInteractionGeometry {
    let center: CGPoint
    let size: CGSize
    let rotation: Double
}

struct EditableDiaryCanvas: View {
    @Binding var diary: DiaryPage
    let stickers: [StickerPost]
    @Binding var layouts: [String: StickerLayout]
    @Binding var selectedElement: CanvasElementID?
    @Binding var activeElement: CanvasElementID?
    @Binding var canvasSize: CGSize
    var backgroundImageData: Data? = nil
    var isDrawingEnabled = false
    var isDrawingPanEnabled = false
    var drawingColorHex = DiaryDrawingStroke.defaultColorHex
    var drawingLineWidth: Double = 5

    @State private var elementFrames: [CanvasElementID: CGRect] = [:]
    @State private var elementBaseSizes: [CanvasElementID: CGSize] = [:]
    @State private var activeDrawingStrokeID: String?

    var body: some View {
        GeometryReader { _ in
            ZStack {
                DiaryBackgroundView(
                    background: diary.background,
                    customImageURL: diary.backgroundImageURL,
                    customImageData: backgroundImageData
                )
                    .contentShape(Rectangle())
                    .zIndex(-2_000_000_000_000)

                ForEach(diary.designItems) { item in
                    let element = CanvasElementID.design(item.id)
                    ZStack {
                        DiaryDesignVisual(
                            item: item,
                            showsConfiguredBorder: selectedElement != element
                        )

                        if selectedElement == element || !item.hasBorder {
                            DiaryDesignShapePath(shape: item.shape)
                                .stroke(
                                    selectedElement == element
                                        ? AppColors.accentPink
                                        : AppColors.accentPink.opacity(0.62),
                                    style: StrokeStyle(
                                        lineWidth: selectedElement == element ? 1.8 : 1.1,
                                        dash: [6, 4]
                                    )
                                )
                                .frame(width: item.width, height: item.height)
                        }
                    }
                    .diaryElementBaseSize(element)
                    .scaleEffect(item.scale)
                    .rotationEffect(.degrees(item.rotation))
                    .diaryElementFrame(element)
                    .position(x: item.x, y: item.y)
                    .allowsHitTesting(false)
                    .zIndex(950_000_000_000 + Double(item.zIndex))
                }

                ForEach(diary.textItems) { item in
                    let element = CanvasElementID.text(item.id)
                    DiaryTextVisual(item: item)
                        .padding(6)
                        .diaryElementBaseSize(element)
                        .scaleEffect(item.scale)
                        .rotationEffect(.degrees(item.rotation))
                        .diaryElementFrame(element)
                        .position(x: item.x, y: item.y)
                        .allowsHitTesting(false)
                        .zIndex(Double(item.zIndex))
                }

                ForEach(diary.stampItems) { item in
                    let element = CanvasElementID.stamp(item.id)
                    DiaryStampVisual(item: item)
                        .padding(8)
                        .diaryElementBaseSize(element)
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
                    DiaryStickerVisual(
                        sticker: sticker,
                        size: DiaryCanvasMetrics.stickerBaseSize,
                        layout: layout,
                        designItems: diary.designItems
                    )
                        .diaryElementBaseSize(element)
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

                DiaryDrawingLayer(strokes: diary.drawingStrokes)
                    .allowsHitTesting(false)
                    .zIndex(900_000_000_000)

                interactionLayer
                    .allowsHitTesting(!isDrawingEnabled)

                if !isDrawingEnabled {
                    selectionOutlineLayer
                }

                if isDrawingEnabled && !isDrawingPanEnabled {
                    drawingInputLayer
                }
            }
            .coordinateSpace(name: "diaryCanvas")
            .contentShape(Rectangle())
            .onPreferenceChange(DiaryElementFramePreferenceKey.self) { frames in
                guard frames != elementFrames else { return }
                elementFrames = frames
            }
            .onPreferenceChange(DiaryElementBaseSizePreferenceKey.self) { sizes in
                guard sizes != elementBaseSizes else { return }
                elementBaseSizes = sizes
            }
            .simultaneousGesture(
                SpatialTapGesture()
                    .onEnded { value in
                        guard !isDrawingEnabled else { return }
                        selectElement(at: value.location)
                    }
            )
            .onChange(of: isDrawingEnabled) { _, enabled in
                if !enabled {
                    activeDrawingStrokeID = nil
                }
            }
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

    private var drawingInputLayer: some View {
        Color.clear
            .contentShape(Rectangle())
            .frame(
                width: DiaryCanvasMetrics.logicalSize.width,
                height: DiaryCanvasMetrics.logicalSize.height
            )
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named("diaryCanvas"))
                    .onChanged { value in
                        appendDrawingPoint(value.location)
                    }
                    .onEnded { _ in
                        activeDrawingStrokeID = nil
                    }
            )
            .accessibilityLabel("手書きキャンバス")
            .accessibilityHint("指またはApple Pencilで線を描きます")
            .zIndex(1_000_000_000_010)
    }

    private func appendDrawingPoint(_ location: CGPoint) {
        let clampedPoint = DiaryDrawingPoint(
            x: min(max(Double(location.x), 0), Double(DiaryCanvasMetrics.logicalSize.width)),
            y: min(max(Double(location.y), 0), Double(DiaryCanvasMetrics.logicalSize.height))
        )

        if let activeDrawingStrokeID,
           let index = diary.drawingStrokes.firstIndex(where: { $0.id == activeDrawingStrokeID }) {
            guard diary.drawingStrokes[index].points.count < 400 else { return }
            if let previous = diary.drawingStrokes[index].points.last {
                let distance = hypot(clampedPoint.x - previous.x, clampedPoint.y - previous.y)
                guard distance >= 1.8 else { return }
            }
            diary.drawingStrokes[index].points.append(clampedPoint)
            return
        }

        if diary.drawingStrokes.count >= 100 {
            diary.drawingStrokes.removeFirst()
        }
        let stroke = DiaryDrawingStroke(
            points: [clampedPoint],
            colorHex: drawingColorHex,
            lineWidth: drawingLineWidth
        )
        diary.drawingStrokes.append(stroke)
        activeDrawingStrokeID = stroke.id
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

    @ViewBuilder
    private func interactionRegion(
        for element: CanvasElementID,
        zIndex: Int
    ) -> some View {
        if let geometry = interactionGeometry(for: element),
           geometry.size.width > 0,
           geometry.size.height > 0,
           geometry.size.width.isFinite,
           geometry.size.height.isFinite,
           geometry.center.x.isFinite,
           geometry.center.y.isFinite {

            Color.clear
                .frame(
                    width: geometry.size.width,
                    height: geometry.size.height
                )
                .contentShape(Rectangle())
                .rotationEffect(.degrees(geometry.rotation))
                .modifier(
                    interactionModifier(
                        for: element,
                        zIndex: zIndex
                    )
                )
                .position(
                    x: geometry.center.x,
                    y: geometry.center.y
                )
        }
    }

    @ViewBuilder
    private var selectionOutlineLayer: some View {
        if let selectedElement,
           shouldShowSolidSelectionOutline(for: selectedElement),
           let geometry = interactionGeometry(for: selectedElement),
           geometry.size.width > 0,
           geometry.size.height > 0,
           geometry.size.width.isFinite,
           geometry.size.height.isFinite {
            RoundedRectangle(cornerRadius: outlineCornerRadius(for: selectedElement), style: .continuous)
                .stroke(AppColors.mainText, lineWidth: 1.5)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .rotationEffect(.degrees(geometry.rotation))
                .position(x: geometry.center.x, y: geometry.center.y)
                .allowsHitTesting(false)
                .zIndex(1_000_000_000_001)
        }
    }

    private func shouldShowSolidSelectionOutline(for element: CanvasElementID) -> Bool {
        if case .design = element {
            return false
        }
        return true
    }

    private func outlineCornerRadius(for element: CanvasElementID) -> CGFloat {
        switch element {
        case .text:
            return AppRadius.chip
        case .stamp:
            return 32
        case .sticker, .design:
            return AppRadius.card
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

        case .design(let id):
            let item = diary.designItems.first { $0.id == id }

            return DiaryElementInteractionModifier(
                element: element,
                zIndex: zIndex,
                x: item?.x ?? 0,
                y: item?.y ?? 0,
                scale: item?.scale ?? 1,
                rotation: item?.rotation ?? 0,
                scaleRange: 0.35...3.5,
                selectedElement: $selectedElement,
                activeElement: $activeElement,
                allowsDirectHitTesting: true,
                updatePosition: { x, y in
                    updateDesign(id) {
                        $0.x = x
                        $0.y = y
                    }
                },
                updateScale: { scale in
                    updateDesign(id) { $0.scale = scale }
                },
                updateRotation: { rotation in
                    updateDesign(id) { $0.rotation = rotation }
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
                scaleRange: DiaryCanvasMetrics.stickerScaleRange,
                selectedElement: $selectedElement,
                activeElement: $activeElement,
                allowsDirectHitTesting: true,
                updatePosition: { x, y in
                    guard let sticker else { return }

                    updateSticker(sticker) {
                        var next = $0
                        next.x = x
                        next.y = y
                        $0 = DiaryCanvasMetrics.sanitizedStickerLayout(next)
                    }
                },
                updateScale: { scale in
                    guard let sticker else { return }

                    updateSticker(sticker) {
                        var next = $0
                        next.scale = scale
                        $0 = DiaryCanvasMetrics.sanitizedStickerLayout(next)
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
            contains(
                location,
                in: interactionGeometry(for: entry.element),
                inset: 8
            )
        }
        .map(\.element)
    }

    private func interactionGeometry(for element: CanvasElementID) -> DiaryInteractionGeometry? {
        switch element {
        case .text(let id):
            guard let item = diary.textItems.first(where: { $0.id == id }) else { return nil }
            let measuredSize = elementBaseSizes[element]
            return DiaryInteractionGeometry(
                center: CGPoint(x: item.x, y: item.y),
                size: scaledSize(
                    measuredSize ?? estimatedTextInteractionSize(item.text),
                    by: item.scale
                ),
                rotation: item.rotation
            )

        case .stamp(let id):
            guard let item = diary.stampItems.first(where: { $0.id == id }) else { return nil }
            return DiaryInteractionGeometry(
                center: CGPoint(x: item.x, y: item.y),
                size: scaledSize(
                    elementBaseSizes[element] ?? CGSize(width: 64, height: 64),
                    by: item.scale
                ),
                rotation: item.rotation
            )

        case .design(let id):
            guard let item = diary.designItems.first(where: { $0.id == id }) else { return nil }
            return DiaryInteractionGeometry(
                center: CGPoint(x: item.x, y: item.y),
                size: scaledSize(
                    elementBaseSizes[element] ?? CGSize(width: item.width, height: item.height),
                    by: item.scale
                ),
                rotation: item.rotation
            )

        case .sticker(let id):
            guard let sticker = stickers.first(where: { $0.id == id }) else { return nil }
            let layout = layouts[id]
                ?? diary.stickerLayout.first(where: { $0.stickerId == id })
                ?? sticker.layout
            let baseSize = DiaryCanvasMetrics.stickerBaseSize
            let canvasCenter = CGPoint(
                x: validCanvasSize.width / 2,
                y: validCanvasSize.height / 2
            )
            return DiaryInteractionGeometry(
                center: CGPoint(
                    x: canvasCenter.x + layout.x,
                    y: canvasCenter.y + layout.y
                ),
                size: scaledSize(
                    elementBaseSizes[element] ?? CGSize(width: baseSize, height: baseSize),
                    by: layout.scale
                ),
                rotation: layout.rotation
            )
        }
    }

    private var validCanvasSize: CGSize {
        guard canvasSize.width > 0,
              canvasSize.height > 0,
              canvasSize.width.isFinite,
              canvasSize.height.isFinite else {
            return DiaryCanvasMetrics.logicalSize
        }
        return canvasSize
    }

    private func scaledSize(_ size: CGSize, by scale: Double) -> CGSize {
        let scale = scale.isFinite ? CGFloat(scale) : 1
        return CGSize(
            width: max(size.width * scale, 1),
            height: max(size.height * scale, 1)
        )
    }

    private func estimatedTextInteractionSize(_ text: String) -> CGSize {
        let lines = max(
            text.split(separator: "\n", omittingEmptySubsequences: false).count,
            1
        )
        let longestLine = text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(\.count)
            .max() ?? text.count
        let width = min(max(CGFloat(longestLine) * 14 + 32, 70), 252)
        let height = CGFloat(lines) * 30 + 24
        return CGSize(width: width, height: max(height, 54))
    }

    private func contains(
        _ point: CGPoint,
        in geometry: DiaryInteractionGeometry?,
        inset: CGFloat = 0
    ) -> Bool {
        guard let geometry else { return false }
        let radians = CGFloat(-geometry.rotation * .pi / 180)
        let dx = point.x - geometry.center.x
        let dy = point.y - geometry.center.y
        let localX = dx * cos(radians) - dy * sin(radians)
        let localY = dx * sin(radians) + dy * cos(radians)
        return abs(localX) <= geometry.size.width / 2 + inset
            && abs(localY) <= geometry.size.height / 2 + inset
    }

    private func updateText(_ id: String, mutate: (inout DiaryTextItem) -> Void) {
        guard let index = diary.textItems.firstIndex(where: { $0.id == id }) else { return }
        mutate(&diary.textItems[index])
    }

    private func updateStamp(_ id: String, mutate: (inout DiaryStampItem) -> Void) {
        guard let index = diary.stampItems.firstIndex(where: { $0.id == id }) else { return }
        mutate(&diary.stampItems[index])
    }

    private func updateDesign(_ id: String, mutate: (inout DiaryDesignItem) -> Void) {
        guard let index = diary.designItems.firstIndex(where: { $0.id == id }) else { return }
        mutate(&diary.designItems[index])
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
        case .design(let id):
            guard let item = diary.designItems.first(where: { $0.id == id }) else { return nil }
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
        case .design(let id):
            guard let item = diary.designItems.first(where: { $0.id == id }) else { return nil }
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
        case .design:
            range = 0.35...3.5
        case .sticker:
            range = DiaryCanvasMetrics.stickerScaleRange
        }
        return min(range.upperBound, max(range.lowerBound, scale))
    }

    private func updateScale(for element: CanvasElementID, scale: Double) {
        switch element {
        case .text(let id):
            updateText(id) { $0.scale = scale }
        case .stamp(let id):
            updateStamp(id) { $0.scale = scale }
        case .design(let id):
            updateDesign(id) { $0.scale = scale }
        case .sticker(let id):
            guard let sticker = stickers.first(where: { $0.id == id }) else { return }
            updateSticker(sticker) {
                var next = $0
                next.scale = scale
                $0 = DiaryCanvasMetrics.sanitizedStickerLayout(next)
            }
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
        case .design(let id):
            updateDesign(id) {
                $0.x = x
                $0.y = y
            }
        case .sticker(let id):
            guard let sticker = stickers.first(where: { $0.id == id }) else { return }
            updateSticker(sticker) {
                var next = $0
                next.x = x
                next.y = y
                $0 = DiaryCanvasMetrics.sanitizedStickerLayout(next)
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
    @State private var interactionGeneration = 0

    private var isActive: Bool { activeElement == element }
    private var isDimmed: Bool { activeElement != nil && !isActive }

    @ViewBuilder
    func body(content: Content) -> some View {
        let base = interactionBase(content)
        if allowsDragGesture && allowsScaleGesture {
            base
                .simultaneousGesture(dragGesture)
                .simultaneousGesture(scaleGesture)
                .simultaneousGesture(rotationGesture)
        } else if allowsDragGesture {
            base
                .simultaneousGesture(dragGesture)
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
            guard !isScaling, !isRotating,
                  value.translation.width.isFinite,
                  value.translation.height.isFinite else { return }

            let origin = dragOrigin ?? CGSize(width: x, height: y)
            guard origin.width.isFinite, origin.height.isFinite else {
                dragOrigin = nil
                return
            }

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
                guard value.isFinite else { return }
                cancelDragForTransformIfNeeded()
                beginInteraction(.scale)
                let origin = scaleOrigin ?? (scale.isFinite ? scale : 1)
                if scaleOrigin == nil { scaleOrigin = origin }
                let candidate = origin * value
                guard candidate.isFinite else { return }
                updateScale(min(scaleRange.upperBound, max(scaleRange.lowerBound, candidate)))
            }
            .onEnded { _ in
                scaleOrigin = nil
                endInteraction(.scale)
            }
    }

    private var rotationGesture: some Gesture {
        RotationGesture()
            .onChanged { value in
                guard value.degrees.isFinite else { return }
                cancelDragForTransformIfNeeded()
                beginInteraction(.rotation)
                let origin = rotationOrigin ?? (rotation.isFinite ? rotation : 0)
                if rotationOrigin == nil { rotationOrigin = origin }
                updateRotation(origin + value.degrees)
            }
            .onEnded { value in
                let origin = rotationOrigin ?? (rotation.isFinite ? rotation : 0)
                if value.degrees.isFinite {
                    updateRotation(normalizedAngle(origin + value.degrees))
                }
                rotationOrigin = nil
                endInteraction(.rotation)
            }
    }

    private enum InteractionKind {
        case drag
        case scale
        case rotation
    }

    private func cancelDragForTransformIfNeeded() {
        guard isDragging else { return }
        if let origin = dragOrigin,
           origin.width.isFinite,
           origin.height.isFinite {
            updatePosition(origin.width, origin.height)
        }
        dragOrigin = nil
        isDragging = false
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

        scheduleInteractionFallbackEnd(for: kind)
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

    private func scheduleInteractionFallbackEnd(for kind: InteractionKind) {
        interactionGeneration += 1
        let generation = interactionGeneration
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(650))
            guard generation == interactionGeneration else { return }
            switch kind {
            case .drag:
                guard isDragging else { return }
                dragOrigin = nil
                isDragging = false
            case .scale:
                guard isScaling else { return }
                scaleOrigin = nil
                isScaling = false
            case .rotation:
                guard isRotating else { return }
                rotationOrigin = nil
                isRotating = false
            }

            if !isDragging && !isScaling && !isRotating && activeElement == element {
                activeElement = nil
            }
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

private struct DiaryElementBaseSizePreferenceKey: PreferenceKey {
    static var defaultValue: [CanvasElementID: CGSize] = [:]

    static func reduce(
        value: inout [CanvasElementID: CGSize],
        nextValue: () -> [CanvasElementID: CGSize]
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
    func diaryElementBaseSize(_ element: CanvasElementID) -> some View {
        background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: DiaryElementBaseSizePreferenceKey.self,
                    value: [element: proxy.size]
                )
            }
        }
    }

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

    for item in diary.designItems {
        entries.append(DiaryLayerEntry(
            element: .design(item.id),
            title: item.effect.title,
            detail: "デザイン",
            systemImage: item.effect.systemImage,
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
        case .design(let id):
            guard let itemIndex = diary.designItems.firstIndex(where: { $0.id == id }) else { continue }
            diary.designItems[itemIndex].zIndex = zIndex
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
            case .design:
                continue
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
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .semibold))

                Text(title)
                    .font(.caption2.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .foregroundStyle(isDisabled ? AppColors.secondaryText : AppColors.mainText)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(
                isDisabled ? AppColors.border.opacity(0.55) : AppColors.accentPink.opacity(0.22),
                in: RoundedRectangle(cornerRadius: AppRadius.chip, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.chip, style: .continuous)
                    .stroke(
                        isDisabled ? AppColors.border : AppColors.accentPink.opacity(0.55),
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityLabel(title)
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
