import Combine
import SwiftUI
import UIKit

private enum BackgroundExtractionState {
    case idle
    case processing
    case ready(UIImage)
    case failure(String)
}

@MainActor
private final class BackgroundRemovalViewModel: ObservableObject {
    @Published private(set) var state: BackgroundExtractionState = .idle

    func extract(from image: UIImage) async {
        state = .processing
        do {
            let foreground = try await ForegroundExtractionService.extract(from: image)
            try Task.checkCancellation()
            state = .ready(foreground)
        } catch is CancellationError {
            state = .idle
        } catch {
            state = .failure(error.localizedDescription)
        }
    }

    func discard() {
        state = .idle
    }
}

struct BackgroundRemovalStickerScreen: View {
    @Environment(\.dismiss) private var dismiss

    let originalImage: UIImage

    @StateObject private var viewModel = BackgroundRemovalViewModel()
    @State private var draft = StickerDraft(creationMode: .backgroundRemoval)
    @State private var extractionAttempt = 0
    @State private var preparedForeground: UIImage?
    @State private var isPreparingPreview = false
    @State private var preparationError: String?
    @State private var generatedPNG: Data?
    @State private var generatedOriginalPNG: Data?
    @State private var isShowingPostScreen = false
    @State private var isInteracting = false
    @State private var isShowingDiscardAlert = false

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .processing:
                processingView
            case .failure(let message):
                failureView(message: message)
            case .ready(let foreground):
                editor(foreground: foreground)
            }
        }
        .background { PetankoMetalBackground() }
        .navigationTitle("背景透過ステッカー")
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
        }
        .navigationDestination(isPresented: $isShowingPostScreen) {
            StickerPostScreen(
                stickerPNG: generatedPNG ?? Data(),
                originalStickerPNG: generatedOriginalPNG,
                draft: draft
            )
        }
        .task(id: extractionAttempt) {
            await viewModel.extract(from: originalImage)
        }
        .onDisappear {
            preparedForeground = nil
            viewModel.discard()
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

    private var processingView: some View {
        VStack(spacing: 18) {
            ProgressView()
                .controlSize(.large)
                .tint(AppColors.mainText)
            Text("人物や物を見つけています…")
                .font(.headline)
                .foregroundStyle(AppColors.mainText)
            Text("処理は端末内だけで行われ、元写真は送信されません。")
                .font(.footnote)
                .foregroundStyle(AppColors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func failureView(message: String) -> some View {
        VStack(spacing: 18) {
            Image(systemName: "person.crop.rectangle.badge.xmark")
                .font(.system(size: 44))
                .foregroundStyle(AppColors.secondaryText)
            Text("背景を透過できませんでした")
                .font(.title3.bold())
                .foregroundStyle(AppColors.mainText)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(AppColors.secondaryText)
                .multilineTextAlignment(.center)

            Button {
                extractionAttempt += 1
            } label: {
                Label("再試行", systemImage: "arrow.clockwise")
            }
            .buttonStyle(PrimaryActionButtonStyle())

            NavigationLink {
                StickerCreationScreen(originalImage: originalImage)
            } label: {
                Label("切り抜きに切り替える", systemImage: "scissors")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .foregroundStyle(AppColors.mainText)
            .background(AppColors.surface.opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous)
                    .stroke(AppColors.border, lineWidth: 0.8)
            }
        }
        .padding(28)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func editor(foreground: UIImage) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                BackgroundForegroundPreview(
                    image: preparedForeground ?? foreground,
                    draft: $draft,
                    isInteracting: $isInteracting
                )
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    if isPreparingPreview {
                        ProgressView()
                            .padding(18)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                }

                ControlSection(title: "配置") {
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .foregroundStyle(AppColors.secondaryText)
                            Slider(value: scaleBinding(for: preparedForeground ?? foreground), in: BackgroundStickerRenderer.scaleRange)
                        }
                        HStack(spacing: 12) {
                            Image(systemName: "rotate.right")
                                .foregroundStyle(AppColors.secondaryText)
                            Slider(value: rotationBinding(for: preparedForeground ?? foreground), in: -180...180)
                        }
                        Button {
                            withAnimation(.easeOut(duration: 0.2)) {
                                draft.foregroundScale = 1
                                draft.foregroundRotation = 0
                                draft.foregroundOffset = .zero
                            }
                        } label: {
                            Label("配置をリセット", systemImage: "arrow.counterclockwise")
                                .font(.subheadline.bold())
                        }
                        .foregroundStyle(AppColors.mainText)
                    }
                }

                ControlSection(title: "デコレーション") {
                    HorizontalOptionPicker(options: StickerDecoration.allCases, selection: $draft.decoration)

                    if draft.decoration.supportsCustomOutlineColor {
                        ColorPicker("ふちの色", selection: outlineColorBinding, supportsOpacity: false)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppColors.mainText)
                    }
                }

                NavigationLink {
                    if let preparedForeground {
                        StickerDetailEditorScreen(
                            preparedForeground: preparedForeground,
                            draft: $draft
                        )
                    }
                } label: {
                    Label("詳細", systemImage: "slider.horizontal.3")
                }
                .buttonStyle(SecondaryActionButtonStyle())
                .disabled(preparedForeground == nil || isPreparingPreview)

                ControlSection(title: "コメント") {
                    TextField("例: 海きれいだった！", text: $draft.comment)
                        .textFieldStyle(.plain)
                        .metalTextField()
                }

                Button {
                    completeSticker(from: foreground)
                } label: {
                    Label("完成", systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .disabled(preparedForeground == nil || isPreparingPreview)

                if let preparationError {
                    Text(preparationError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 28)
        }
        .scrollDisabled(isInteracting)
        .task(id: PreviewPreparationKey(decoration: draft.decoration, outlineColorHex: draft.outlineColorHex)) {
            await preparePreview(from: foreground)
        }
    }

    private var hasUnsavedChanges: Bool {
        draft != StickerDraft(creationMode: .backgroundRemoval)
    }

    private func requestDismiss() {
        if hasUnsavedChanges {
            isShowingDiscardAlert = true
        } else {
            dismiss()
        }
    }

    private var outlineColorBinding: Binding<Color> {
        Binding(
            get: {
                Color(uiColor: UIColor(hex: draft.outlineColorHex) ?? .white)
            },
            set: { color in
                draft.outlineColorHex = UIColor(color).petankoHexString
            }
        )
    }

    private func scaleBinding(for image: UIImage) -> Binding<Double> {
        Binding(
            get: { draft.foregroundScale },
            set: { value in
                draft.foregroundScale = value.clamped(to: BackgroundStickerRenderer.scaleRange)
                constrainOffset(for: image)
            }
        )
    }

    private func rotationBinding(for image: UIImage) -> Binding<Double> {
        Binding(
            get: { draft.foregroundRotation },
            set: { value in
                draft.foregroundRotation = normalizedAngle(value)
                constrainOffset(for: image)
            }
        )
    }

    private func constrainOffset(for image: UIImage) {
        draft.foregroundOffset = BackgroundStickerRenderer.constrainedOffset(
            draft.foregroundOffset,
            imageSize: image.size,
            canvasSize: BackgroundStickerRenderer.canvasSize,
            scale: draft.foregroundScale,
            rotation: draft.foregroundRotation
        )
    }

    private func preparePreview(from foreground: UIImage) async {
        isPreparingPreview = true
        preparationError = nil
        await Task.yield()
        do {
            let image = try BackgroundStickerRenderer.prepareForeground(
                foreground,
                decoration: draft.decoration,
                outlineColor: UIColor(hex: draft.outlineColorHex) ?? .white
            )
            try Task.checkCancellation()
            preparedForeground = image
            constrainOffset(for: image)
        } catch is CancellationError {
            return
        } catch {
            preparationError = error.localizedDescription
        }
        isPreparingPreview = false
    }

    private func completeSticker(from foreground: UIImage) {
        guard let preparedForeground else { return }
        do {
            draft.creationMode = .backgroundRemoval
            generatedPNG = try BackgroundStickerRenderer.renderPNG(
                preparedForeground: preparedForeground,
                draft: draft
            )
            generatedOriginalPNG = nil
            isShowingPostScreen = true
        } catch {
            preparationError = error.localizedDescription
        }
    }
}

private struct PreviewPreparationKey: Equatable {
    let decoration: StickerDecoration
    let outlineColorHex: String
}

private struct BackgroundForegroundPreview: View {
    let image: UIImage
    @Binding var draft: StickerDraft
    @Binding var isInteracting: Bool

    @State private var dragStart: CGSize?
    @State private var scaleStart: Double?
    @State private var rotationStart: Double?
    @State private var isDragging = false
    @State private var isMagnifying = false
    @State private var isRotating = false

    var body: some View {
        GeometryReader { proxy in
            let displayedRotation = draft.foregroundRotation
            let saveSide = min(proxy.size.width * 0.9, proxy.size.height * 0.9)
            let previewImage = (try? BackgroundStickerRenderer.renderImage(
                preparedForeground: image,
                draft: draft
            )) ?? image

            ZStack {
                BackgroundCheckerboard()
                Image(uiImage: previewImage)
                    .resizable()
                    .interpolation(.medium)
                    .frame(width: saveSide, height: saveSide)

                StickerSaveAreaGuide()
                    .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .clipped()
            .highPriorityGesture(dragGesture(saveSide: saveSide, rotation: displayedRotation))
            .simultaneousGesture(magnificationGesture(rotation: displayedRotation))
            .simultaneousGesture(rotationGesture())
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .stroke(AppColors.border, lineWidth: 0.8)
            }
        }
    }

    private func dragGesture(saveSide: CGFloat, rotation: Double) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                isDragging = true
                updateInteractionState()
                let start = dragStart ?? draft.foregroundOffset
                dragStart = start
                let proposed = CGSize(
                    width: start.width + value.translation.width / max(saveSide, 1),
                    height: start.height + value.translation.height / max(saveSide, 1)
                )
                draft.foregroundOffset = constrained(proposed, rotation: rotation)
            }
            .onEnded { _ in
                dragStart = nil
                isDragging = false
                updateInteractionState()
            }
    }

    private func magnificationGesture(rotation: Double) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                isMagnifying = true
                updateInteractionState()
                let start = scaleStart ?? draft.foregroundScale
                scaleStart = start
                draft.foregroundScale = (start * Double(value)).clamped(to: BackgroundStickerRenderer.scaleRange)
                draft.foregroundOffset = constrained(draft.foregroundOffset, rotation: rotation)
            }
            .onEnded { _ in
                scaleStart = nil
                isMagnifying = false
                updateInteractionState()
            }
    }

    private func rotationGesture() -> some Gesture {
        RotationGesture()
            .onChanged { value in
                isRotating = true
                updateInteractionState()
                if rotationStart == nil {
                    rotationStart = draft.foregroundRotation
                }
                draft.foregroundRotation = normalizedAngle((rotationStart ?? 0) + value.degrees)
                draft.foregroundOffset = constrained(
                    draft.foregroundOffset,
                    rotation: draft.foregroundRotation
                )
            }
            .onEnded { value in
                draft.foregroundRotation = normalizedAngle((rotationStart ?? draft.foregroundRotation) + value.degrees)
                rotationStart = nil
                draft.foregroundOffset = constrained(
                    draft.foregroundOffset,
                    rotation: draft.foregroundRotation
                )
                isRotating = false
                updateInteractionState()
            }
    }

    private func constrained(_ offset: CGSize, rotation: Double) -> CGSize {
        BackgroundStickerRenderer.constrainedOffset(
            offset,
            imageSize: image.size,
            canvasSize: BackgroundStickerRenderer.canvasSize,
            scale: draft.foregroundScale,
            rotation: rotation
        )
    }

    private func updateInteractionState() {
        isInteracting = isDragging || isMagnifying || isRotating
    }
}

private struct StickerSaveAreaGuide: View {
    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width * 0.9, proxy.size.height * 0.9)
            let rect = CGRect(
                x: (proxy.size.width - side) / 2,
                y: (proxy.size.height - side) / 2,
                width: side,
                height: side
            )

            Path { path in
                path.addRect(CGRect(origin: .zero, size: proxy.size))
                path.addRect(rect)
            }
            .fill(.black.opacity(0.38), style: FillStyle(eoFill: true))

            Rectangle()
                .stroke(.red, lineWidth: 2)
                .frame(width: side, height: side)
                .position(x: rect.midX, y: rect.midY)
        }
    }
}

private enum StickerDetailEditorTab: String, CaseIterable, Identifiable {
    case shape = "図形"
    case filter = "フィルター"

    var id: String { rawValue }
}

private enum StickerDetailEditorMetrics {
    static let canvasHorizontalPadding: CGFloat = 16
    static let sheetHorizontalPadding: CGFloat = 20
    static let sheetTopPadding: CGFloat = 14
    static let sheetBottomPadding: CGFloat = 12
    static let sectionPadding: CGFloat = 16
}

private struct StickerDetailEditorScreen: View {
    @Environment(\.dismiss) private var dismiss

    let preparedForeground: UIImage
    @Binding private var parentDraft: StickerDraft
    private let originalDraft: StickerDraft
    @State private var draft: StickerDraft
    @State private var selectedElement: StickerDetailElementID?
    @State private var activeElement: StickerDetailElementID?
    @State private var isInteracting = false
    @State private var selectedEditorTab: StickerDetailEditorTab = .shape
    @State private var isShowingDiscardAlert = false
    @State private var customPaletteColors: [String: Color] = [:]
    @State private var customPaletteSelectionIDs: Set<String> = []

    init(preparedForeground: UIImage, draft: Binding<StickerDraft>) {
        self.preparedForeground = preparedForeground
        _parentDraft = draft
        originalDraft = draft.wrappedValue
        _draft = State(initialValue: draft.wrappedValue)
    }

    private let palette = [
        "#E11D48",
        "#F7B267",
        "#6AA84F",
        "#4F8AE8",
        "#FFFFFF",
        "#1F1B18",
        StickerDetailShapeItem.transparentColorHex
    ]

    var body: some View {
        GeometryReader { proxy in
            let screenWidth = proxy.size.width
            let canvasHorizontalPadding = StickerDetailEditorMetrics.canvasHorizontalPadding
            let canvasSide = max(1, screenWidth - canvasHorizontalPadding * 4)

            ZStack(alignment: .bottom) {
                VStack(spacing: 12) {
                    StickerDetailCanvas(
                        preparedForeground: preparedForeground,
                        draft: $draft,
                        selectedElement: $selectedElement,
                        activeElement: $activeElement,
                        isInteracting: $isInteracting
                    )
                    .frame(width: canvasSide, height: canvasSide)
                    .padding(.top, 12)
                    .padding(.horizontal, canvasHorizontalPadding)

                    Spacer(minLength: 0)
                }
                .frame(width: screenWidth, height: proxy.size.height, alignment: .top)

                editorBottomSheet
                    .frame(width: screenWidth)
            }
            .frame(width: screenWidth, height: proxy.size.height)
            .clipped()
        }
        .background { PetankoMetalBackground() }
        .navigationTitle("詳細編集")
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
                Button("完了") {
                    parentDraft = draft
                    dismiss()
                }
                .fontWeight(.bold)
                .foregroundStyle(AppColors.accentPink)
            }
        }
        .onChange(of: selectedElement) { _, element in
            switch element {
            case .shape:
                selectedEditorTab = .shape
            case .filter:
                selectedEditorTab = .filter
            case nil:
                break
            }
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

    private var editorBottomSheet: some View {
        VStack(spacing: 0) {
            if selectedElement == nil {
                VStack(spacing: 14) {
                    editorTabContent
                }
                .padding(.horizontal, StickerDetailEditorMetrics.sheetHorizontalPadding)
                .padding(.top, StickerDetailEditorMetrics.sheetTopPadding)
                .padding(.bottom, StickerDetailEditorMetrics.sheetBottomPadding)
            } else {
                ScrollView {
                    VStack(spacing: 14) {
                        editorTabContent
                    }
                    .padding(.horizontal, StickerDetailEditorMetrics.sheetHorizontalPadding)
                    .padding(.top, StickerDetailEditorMetrics.sheetTopPadding)
                    .padding(.bottom, StickerDetailEditorMetrics.sheetBottomPadding)
                }
                .frame(maxHeight: 300)
                .scrollDisabled(isInteracting)
            }

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
                ForEach(StickerDetailEditorTab.allCases) { tab in
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
                            .frame(minWidth: 92)
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
    }

    private var hasUnsavedChanges: Bool {
        draft != originalDraft
    }

    private func requestDismiss() {
        if hasUnsavedChanges {
            isShowingDiscardAlert = true
        } else {
            dismiss()
        }
    }

    @ViewBuilder
    private var editorTabContent: some View {
        switch selectedEditorTab {
        case .shape:
            if case .shape(let id) = selectedElement {
                shapeControls(id: id)
            } else {
                optionRow(options: StickerDetailShapeKind.allCases) { kind in
                    addShape(kind)
                }
            }
        case .filter:
            if case .filter(let id) = selectedElement {
                filterControls(id: id)
            } else {
                optionRow(options: StickerDetailFilterKind.allCases) { kind in
                    addFilter(kind)
                }
            }
        }
    }

    private func optionRow<Option: PetankoOption>(
        options: [Option],
        action: @escaping (Option) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(options, id: \.id) { option in
                        Button {
                            action(option)
                        } label: {
                            Label(option.title, systemImage: option.systemImage)
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .background(AppColors.surface.opacity(0.92), in: Capsule())
                                .overlay {
                                    Capsule()
                                        .stroke(AppColors.border, lineWidth: 0.8)
                                }
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(AppColors.mainText)
                    }
                }
            }
        }
    }

    private func shapeControls(id: String) -> some View {
        DetailControlSection(title: "図形") {
            if draft.detailEdit.shapes.firstIndex(where: { $0.id == id }) != nil {
                VStack(spacing: 13) {
                    HorizontalOptionPicker(
                        options: StickerDetailShapeKind.allCases,
                        selection: shapeTypeBinding(id: id)
                    )

                    Toggle("フィルターを有効化", isOn: shapeFilterEnabledBinding(id: id))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColors.mainText)

                    sliderRow(
                        title: "横幅",
                        systemImage: "arrow.left.and.right",
                        value: shapeWidthBinding(id: id),
                        range: 36...420
                    )
                    sliderRow(
                        title: "高さ",
                        systemImage: "arrow.up.and.down",
                        value: shapeHeightBinding(id: id),
                        range: 36...420
                    )
                    sliderRow(
                        title: "枠の太さ",
                        systemImage: "circle.dashed",
                        value: shapeStrokeWidthBinding(id: id),
                        range: 0...28
                    )

                    colorPalette(
                        title: "塗りつぶし色",
                        customSelectionID: "shape-\(id)-fill",
                        selection: shapeFillColorBinding(id: id)
                    )
                    colorPalette(
                        title: "枠色",
                        customSelectionID: "shape-\(id)-stroke",
                        selection: shapeStrokeColorBinding(id: id)
                    )

                    deleteButton {
                        selectedElement = nil
                        activeElement = nil
                        draft.detailEdit.shapes.removeAll { $0.id == id }
                    }
                }
            }
        }
    }

    private func filterControls(id: String) -> some View {
        DetailControlSection(title: "フィルター") {
            if let index = draft.detailEdit.filters.firstIndex(where: { $0.id == id }) {
                VStack(spacing: 13) {
                    HorizontalOptionPicker(
                        options: StickerDetailFilterKind.allCases,
                        selection: filterTypeBinding(id: id)
                    )

                    Divider()

                    HorizontalOptionPicker(
                        options: StickerDetailShapeKind.allCases,
                        selection: filterShapeBinding(id: id)
                    )

                    sliderRow(
                        title: "横幅",
                        systemImage: "arrow.left.and.right",
                        value: filterWidthBinding(id: id),
                        range: 36...450
                    )
                    sliderRow(
                        title: "高さ",
                        systemImage: "arrow.up.and.down",
                        value: filterHeightBinding(id: id),
                        range: 36...450
                    )

                    if draft.detailEdit.filters[index].type == .translucentColor {
                        colorPalette(
                            title: "色",
                            customSelectionID: "filter-\(id)-color",
                            selection: filterColorBinding(id: id),
                            includesTransparent: false
                        )
                        sliderRow(
                            title: "透明度",
                            systemImage: "circle.lefthalf.filled",
                            value: filterOpacityBinding(id: id),
                            range: 0.05...1
                        )
                    }

                    if draft.detailEdit.filters[index].type == .pixelate {
                        sliderRow(
                            title: "粒の大きさ",
                            systemImage: "square.grid.3x3.fill",
                            value: filterPixelScaleBinding(id: id),
                            range: 4...32
                        )
                    }

                    deleteButton {
                        selectedElement = nil
                        activeElement = nil
                        draft.detailEdit.filters.removeAll { $0.id == id }
                    }
                }
            }
        }
    }

    private func sliderRow(
        title: String,
        systemImage: String,
        value: Binding<Double>,
        range: ClosedRange<Double>
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(AppColors.secondaryText)
                .frame(width: 22)
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppColors.secondaryText)
                .frame(width: 72, alignment: .leading)
            Slider(value: value, in: range)
        }
    }

    private func colorPalette(
        title: String,
        customSelectionID: String,
        selection: Binding<String>,
        includesTransparent: Bool = true
    ) -> some View {
        let isCustomSelected = customPaletteSelectionIDs.contains(customSelectionID)

        return VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppColors.secondaryText)

            HStack(spacing: 8) {
                ColorPicker(
                    selection: customPaletteColorBinding(selection, customSelectionID: customSelectionID),
                    supportsOpacity: false
                ) {
                    paletteCircle(
                        color: customPaletteDisplayColor(selection, customSelectionID: customSelectionID),
                        isSelected: false,
                        isTransparent: false
                    )
                }
                .labelsHidden()
                .buttonStyle(.plain)
                .frame(width: 38, height: 38)
                .overlay {
                    if isCustomSelected {
                        Circle()
                            .stroke(AppColors.accentPink, lineWidth: 3)
                            .frame(width: 36, height: 36)
                            .allowsHitTesting(false)
                    }
                }

                ForEach(palette.filter { includesTransparent || $0 != StickerDetailShapeItem.transparentColorHex }, id: \.self) { hex in
                    Button {
                        customPaletteSelectionIDs.remove(customSelectionID)
                        selection.wrappedValue = hex
                    } label: {
                        paletteCircle(
                            color: paletteColor(hex),
                            isSelected: !isCustomSelected && selection.wrappedValue == hex,
                            isTransparent: hex == StickerDetailShapeItem.transparentColorHex
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func customPaletteColorBinding(_ selection: Binding<String>, customSelectionID: String) -> Binding<Color> {
        Binding(
            get: { customPaletteDisplayColor(selection, customSelectionID: customSelectionID) },
            set: { color in
                customPaletteColors[customSelectionID] = color
                customPaletteSelectionIDs.insert(customSelectionID)
                selection.wrappedValue = UIColor(color).petankoHexString
            }
        )
    }

    private func customPaletteDisplayColor(_ selection: Binding<String>, customSelectionID: String) -> Color {
        customPaletteColors[customSelectionID] ?? customPaletteFallbackColor(selection.wrappedValue)
    }

    private func customPaletteFallbackColor(_ hex: String) -> Color {
        if hex == StickerDetailShapeItem.transparentColorHex {
            return Color(uiColor: .systemPink)
        }
        return paletteColor(hex)
    }

    private func paletteCircle(
        color: Color,
        isSelected: Bool,
        isTransparent: Bool
    ) -> some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: 30, height: 30)
                .overlay {
                    Circle()
                        .stroke(AppColors.border, lineWidth: 1)
                }
            if isTransparent {
                Image(systemName: "slash.circle")
                    .font(.caption.bold())
                    .foregroundStyle(AppColors.mainText)
            }
            Circle()
                .stroke(isSelected ? AppColors.accentPink : AppColors.border, lineWidth: isSelected ? 3 : 1)
                .frame(width: 36, height: 36)
        }
        .frame(width: 38, height: 38)
    }

    private func paletteColor(_ hex: String) -> Color {
        if hex == StickerDetailShapeItem.transparentColorHex {
            return Color.white.opacity(0.18)
        }
        return Color(uiColor: UIColor(hex: hex) ?? .systemPink)
    }

    private func deleteButton(action: @escaping () -> Void) -> some View {
        Button(role: .destructive) {
            action()
        } label: {
            Label("削除", systemImage: "trash")
        }
        .buttonStyle(SecondaryActionButtonStyle(foregroundColor: AppColors.destructiveRed))
    }

    private func addShape(_ kind: StickerDetailShapeKind) {
        let color = ["#E11D48", "#F7B267", "#6AA84F", "#4F8AE8"].randomElement() ?? "#F7B267"
        let side = 150.0
        let item = StickerDetailShapeItem(
            type: kind,
            x: side / 2,
            y: side / 2,
            width: side,
            height: side,
            fillColorHex: color,
            zIndex: draft.detailEdit.nextOrder()
        )
        draft.detailEdit.shapes.append(item)
        selectedElement = .shape(item.id)
    }

    private func addFilter(_ kind: StickerDetailFilterKind) {
        let item = StickerDetailFilterItem(
            type: kind,
            opacity: defaultOpacity(for: kind),
            zIndex: draft.detailEdit.nextOrder()
        )
        draft.detailEdit.filters.append(item)
        selectedElement = .filter(item.id)
    }

    private func defaultOpacity(for kind: StickerDetailFilterKind) -> Double {
        kind == .translucentColor ? 0.45 : 1
    }

    private func shapeTypeBinding(id: String) -> Binding<StickerDetailShapeKind> {
        Binding(
            get: { shape(id)?.type ?? .rectangle },
            set: { value in updateShape(id) { $0.type = value } }
        )
    }

    private func shapeFilterEnabledBinding(id: String) -> Binding<Bool> {
        Binding(
            get: { shape(id)?.isFilterEnabled ?? true },
            set: { value in updateShape(id) { $0.isFilterEnabled = value } }
        )
    }

    private func shapeWidthBinding(id: String) -> Binding<Double> {
        Binding(
            get: { shape(id)?.width ?? 150 },
            set: { value in updateShape(id) { $0.width = value } }
        )
    }

    private func shapeHeightBinding(id: String) -> Binding<Double> {
        Binding(
            get: { shape(id)?.height ?? 150 },
            set: { value in updateShape(id) { $0.height = value } }
        )
    }

    private func shapeStrokeWidthBinding(id: String) -> Binding<Double> {
        Binding(
            get: { shape(id)?.strokeWidth ?? 0 },
            set: { value in updateShape(id) { $0.strokeWidth = value } }
        )
    }

    private func shapeFillColorBinding(id: String) -> Binding<String> {
        Binding(
            get: { shape(id)?.fillColorHex ?? StickerDetailShapeItem.transparentColorHex },
            set: { value in updateShape(id) { $0.fillColorHex = value } }
        )
    }

    private func shapeStrokeColorBinding(id: String) -> Binding<String> {
        Binding(
            get: { shape(id)?.strokeColorHex ?? StickerDetailShapeItem.transparentColorHex },
            set: { value in updateShape(id) { $0.strokeColorHex = value } }
        )
    }

    private func filterTypeBinding(id: String) -> Binding<StickerDetailFilterKind> {
        Binding(
            get: { filter(id)?.type ?? .invert },
            set: { value in updateFilter(id) { $0.type = value } }
        )
    }

    private func filterShapeBinding(id: String) -> Binding<StickerDetailShapeKind> {
        Binding(
            get: { filter(id)?.maskShape ?? .rectangle },
            set: { value in updateFilter(id) { $0.maskShape = value } }
        )
    }

    private func filterWidthBinding(id: String) -> Binding<Double> {
        Binding(
            get: { filter(id)?.width ?? 180 },
            set: { value in updateFilter(id) { $0.width = value } }
        )
    }

    private func filterHeightBinding(id: String) -> Binding<Double> {
        Binding(
            get: { filter(id)?.height ?? 130 },
            set: { value in updateFilter(id) { $0.height = value } }
        )
    }

    private func filterColorBinding(id: String) -> Binding<String> {
        Binding(
            get: { filter(id)?.colorHex ?? "#E11D48" },
            set: { value in updateFilter(id) { $0.colorHex = value } }
        )
    }

    private func filterOpacityBinding(id: String) -> Binding<Double> {
        Binding(
            get: { filter(id)?.opacity ?? 1 },
            set: { value in updateFilter(id) { $0.opacity = value } }
        )
    }

    private func filterPixelScaleBinding(id: String) -> Binding<Double> {
        Binding(
            get: { filter(id)?.pixelScale ?? 12 },
            set: { value in updateFilter(id) { $0.pixelScale = value } }
        )
    }

    private func shape(_ id: String) -> StickerDetailShapeItem? {
        draft.detailEdit.shapes.first { $0.id == id }
    }

    private func filter(_ id: String) -> StickerDetailFilterItem? {
        draft.detailEdit.filters.first { $0.id == id }
    }

    private func updateShape(_ id: String, mutate: (inout StickerDetailShapeItem) -> Void) {
        guard let index = draft.detailEdit.shapes.firstIndex(where: { $0.id == id }) else { return }
        mutate(&draft.detailEdit.shapes[index])
    }

    private func updateFilter(_ id: String, mutate: (inout StickerDetailFilterItem) -> Void) {
        guard let index = draft.detailEdit.filters.firstIndex(where: { $0.id == id }) else { return }
        mutate(&draft.detailEdit.filters[index])
    }
}

private struct StickerDetailCanvas: View {
    let preparedForeground: UIImage
    @Binding var draft: StickerDraft
    @Binding var selectedElement: StickerDetailElementID?
    @Binding var activeElement: StickerDetailElementID?
    @Binding var isInteracting: Bool

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width * 0.9, proxy.size.height * 0.9)
            let origin = CGPoint(
                x: (proxy.size.width - side) / 2,
                y: (proxy.size.height - side) / 2
            )
            let previewImage = (try? BackgroundStickerRenderer.renderImage(
                preparedForeground: preparedForeground,
                draft: draft
            )) ?? preparedForeground

            ZStack {
                BackgroundCheckerboard()

                Image(uiImage: previewImage)
                    .resizable()
                    .interpolation(.medium)
                    .frame(width: side, height: side)
                    .position(x: origin.x + side / 2, y: origin.y + side / 2)

                filterGuideLayer(side: side, origin: origin)
                    .allowsHitTesting(false)

                objectInteractionLayer(side: side, origin: origin)
                selectionOutlineLayer(side: side, origin: origin)
                    .allowsHitTesting(false)

                StickerSaveAreaGuide()
                    .allowsHitTesting(false)
            }
            .coordinateSpace(name: "stickerDetailCanvas")
            .contentShape(Rectangle())
            .simultaneousGesture(
                SpatialTapGesture()
                    .onEnded { value in
                        selectElement(at: value.location, side: side, origin: origin)
                    }
            )
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .stroke(AppColors.border, lineWidth: 0.8)
            }
        }
    }

    @ViewBuilder
    private func filterGuideLayer(side: CGFloat, origin: CGPoint) -> some View {
        ForEach(draft.detailEdit.filters.sorted { $0.zIndex < $1.zIndex }) { item in
            if let geometry = interactionGeometry(for: .filter(item.id), side: side, origin: origin) {
                StickerDetailShapePath(kind: item.maskShape)
                    .stroke(
                        Color.yellow,
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [6, 4])
                    )
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .rotationEffect(.degrees(geometry.rotation))
                    .position(geometry.displayCenter)
            }
        }
    }

    @ViewBuilder
    private func objectInteractionLayer(side: CGFloat, origin: CGPoint) -> some View {
        ForEach(layerEntries, id: \.element) { entry in
            if let geometry = interactionGeometry(for: entry.element, side: side, origin: origin) {
                interactionRegion(
                    element: entry.element,
                    geometry: geometry,
                    zIndex: entry.zIndex
                )
            }
        }
    }

    @ViewBuilder
    private func selectionOutlineLayer(side: CGFloat, origin: CGPoint) -> some View {
        if let selectedElement,
           let geometry = interactionGeometry(for: selectedElement, side: side, origin: origin) {
            let outlineColor: Color = {
                switch selectedElement {
                case .filter:
                    return .yellow
                case .shape:
                    return AppColors.mainText
                }
            }()

            StickerDetailShapePath(kind: shapeKind(for: selectedElement))
                .stroke(outlineColor, lineWidth: 1.6)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .rotationEffect(.degrees(geometry.rotation))
                .position(geometry.displayCenter)
                .zIndex(1_000_000_000_001)
        }
    }

    private func interactionRegion(
        element: StickerDetailElementID,
        geometry: StickerDetailInteractionGeometry,
        zIndex: Int
    ) -> some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: geometry.size.width, height: geometry.size.height)
            .contentShape(Rectangle())
            .rotationEffect(.degrees(geometry.rotation))
            .modifier(
                StickerDetailElementInteractionModifier(
                    element: element,
                    zIndex: zIndex,
                    x: geometry.canvasCenter.x,
                    y: geometry.canvasCenter.y,
                    displayScale: geometry.displayScale,
                    scale: elementScale(element),
                    rotation: geometry.rotation,
                    selectedElement: $selectedElement,
                    activeElement: $activeElement,
                    isInteracting: $isInteracting,
                    updatePosition: { x, y in
                        updatePosition(for: element, x: x, y: y)
                    },
                    updateScale: { scale in
                        updateScale(for: element, scale: scale)
                    },
                    updateRotation: { rotation in
                        updateRotation(for: element, rotation: rotation)
                    }
                )
            )
            .position(geometry.displayCenter)
    }

    private var layerEntries: [StickerDetailLayerEntry] {
        var entries: [StickerDetailLayerEntry] = []
        for item in draft.detailEdit.filters {
            entries.append(StickerDetailLayerEntry(
                element: .filter(item.id),
                zIndex: 1_000_000 + item.zIndex
            ))
        }
        for item in draft.detailEdit.shapes {
            entries.append(StickerDetailLayerEntry(
                element: .shape(item.id),
                zIndex: item.zIndex
            ))
        }
        return entries.sorted { $0.zIndex > $1.zIndex }
    }

    private func selectElement(at location: CGPoint, side: CGFloat, origin: CGPoint) {
        let elements = layerEntries
            .filter { entry in
                contains(
                    location,
                    in: interactionGeometry(for: entry.element, side: side, origin: origin),
                    inset: 8
                )
            }
            .map(\.element)

        guard !elements.isEmpty else {
            selectedElement = nil
            activeElement = nil
            return
        }

        if let currentSelection = selectedElement,
           let currentIndex = elements.firstIndex(of: currentSelection) {
            selectedElement = elements[(currentIndex + 1) % elements.count]
        } else {
            selectedElement = elements[0]
        }
        activeElement = nil
    }

    private func interactionGeometry(
        for element: StickerDetailElementID,
        side: CGFloat,
        origin: CGPoint
    ) -> StickerDetailInteractionGeometry? {
        let displayScale = side / BackgroundStickerRenderer.canvasSize.width
        let center = elementCenter(element)
        let size = elementSize(element)
        guard size.width > 0,
              size.height > 0,
              center.x.isFinite,
              center.y.isFinite else { return nil }

        let displayCenter = CGPoint(
            x: origin.x + center.x * displayScale,
            y: origin.y + center.y * displayScale
        )
        let displaySize = CGSize(
            width: max(size.width * displayScale, 44),
            height: max(size.height * displayScale, 44)
        )
        return StickerDetailInteractionGeometry(
            canvasCenter: center,
            displayCenter: displayCenter,
            size: displaySize,
            rotation: elementRotation(element),
            displayScale: displayScale
        )
    }

    private func elementCenter(_ element: StickerDetailElementID) -> CGPoint {
        switch element {
        case .shape(let id):
            guard let item = draft.detailEdit.shapes.first(where: { $0.id == id }) else {
                return CGPoint(x: 256, y: 256)
            }
            return CGPoint(x: item.x, y: item.y)
        case .filter(let id):
            guard let item = draft.detailEdit.filters.first(where: { $0.id == id }) else {
                return CGPoint(x: 256, y: 256)
            }
            return CGPoint(x: item.x, y: item.y)
        }
    }

    private func elementSize(_ element: StickerDetailElementID) -> CGSize {
        switch element {
        case .shape(let id):
            guard let item = draft.detailEdit.shapes.first(where: { $0.id == id }) else {
                return CGSize(width: 120, height: 120)
            }
            return CGSize(width: item.width * item.scale, height: item.height * item.scale)
        case .filter(let id):
            guard let item = draft.detailEdit.filters.first(where: { $0.id == id }) else {
                return CGSize(width: 120, height: 120)
            }
            return CGSize(width: item.width * item.scale, height: item.height * item.scale)
        }
    }

    private func shapeKind(for element: StickerDetailElementID) -> StickerDetailShapeKind {
        switch element {
        case .shape(let id):
            draft.detailEdit.shapes.first(where: { $0.id == id })?.type ?? .rectangle
        case .filter(let id):
            draft.detailEdit.filters.first(where: { $0.id == id })?.maskShape ?? .rectangle
        }
    }

    private func elementScale(_ element: StickerDetailElementID) -> Double {
        switch element {
        case .shape(let id):
            draft.detailEdit.shapes.first(where: { $0.id == id })?.scale ?? 1
        case .filter(let id):
            draft.detailEdit.filters.first(where: { $0.id == id })?.scale ?? 1
        }
    }

    private func elementRotation(_ element: StickerDetailElementID) -> Double {
        switch element {
        case .shape(let id):
            draft.detailEdit.shapes.first(where: { $0.id == id })?.rotation ?? 0
        case .filter(let id):
            draft.detailEdit.filters.first(where: { $0.id == id })?.rotation ?? 0
        }
    }

    private func updatePosition(for element: StickerDetailElementID, x: Double, y: Double) {
        updateElement(element) { itemX, itemY, _, _ in
            itemX = x.clamped(to: -120...632)
            itemY = y.clamped(to: -120...632)
        }
    }

    private func updateScale(for element: StickerDetailElementID, scale: Double) {
        updateElement(element) { _, _, itemScale, _ in
            itemScale = scale.clamped(to: 0.35...3.5)
        }
    }

    private func updateRotation(for element: StickerDetailElementID, rotation: Double) {
        updateElement(element) { _, _, _, itemRotation in
            itemRotation = normalizedAngle(rotation)
        }
    }

    private func updateElement(_ element: StickerDetailElementID, mutate: (inout Double, inout Double, inout Double, inout Double) -> Void) {
        switch element {
        case .shape(let id):
            guard let index = draft.detailEdit.shapes.firstIndex(where: { $0.id == id }) else { return }
            var item = draft.detailEdit.shapes[index]
            mutate(
                &item.x,
                &item.y,
                &item.scale,
                &item.rotation
            )
            draft.detailEdit.shapes[index] = item
        case .filter(let id):
            guard let index = draft.detailEdit.filters.firstIndex(where: { $0.id == id }) else { return }
            var item = draft.detailEdit.filters[index]
            mutate(
                &item.x,
                &item.y,
                &item.scale,
                &item.rotation
            )
            draft.detailEdit.filters[index] = item
        }
    }

    private func contains(
        _ point: CGPoint,
        in geometry: StickerDetailInteractionGeometry?,
        inset: CGFloat = 0
    ) -> Bool {
        guard let geometry else { return false }
        let radians = CGFloat(-geometry.rotation * .pi / 180)
        let dx = point.x - geometry.displayCenter.x
        let dy = point.y - geometry.displayCenter.y
        let localX = dx * cos(radians) - dy * sin(radians)
        let localY = dx * sin(radians) + dy * cos(radians)
        return abs(localX) <= geometry.size.width / 2 + inset
            && abs(localY) <= geometry.size.height / 2 + inset
    }
}

private struct StickerDetailLayerEntry: Hashable {
    let element: StickerDetailElementID
    let zIndex: Int
}

private struct DetailControlSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: title)
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
    }
}

private struct StickerDetailInteractionGeometry {
    let canvasCenter: CGPoint
    let displayCenter: CGPoint
    let size: CGSize
    let rotation: Double
    let displayScale: CGFloat
}

private struct StickerDetailElementInteractionModifier: ViewModifier {
    let element: StickerDetailElementID
    let zIndex: Int
    let x: Double
    let y: Double
    let displayScale: CGFloat
    let scale: Double
    let rotation: Double
    @Binding var selectedElement: StickerDetailElementID?
    @Binding var activeElement: StickerDetailElementID?
    @Binding var isInteracting: Bool
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

    private var canReceiveInteraction: Bool {
        guard let selectedElement else { return true }
        return selectedElement == element
    }

    func body(content: Content) -> some View {
        content
            .zIndex(Double(zIndex))
            .allowsHitTesting(canReceiveInteraction)
            .simultaneousGesture(dragGesture)
            .simultaneousGesture(scaleGesture)
            .simultaneousGesture(rotationGesture)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("stickerDetailCanvas"))
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
                let safeDisplayScale = max(displayScale, 0.001)
                updatePosition(
                    origin.width + value.translation.width / safeDisplayScale,
                    origin.height + value.translation.height / safeDisplayScale
                )
            }
            .onEnded { _ in
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
                updateScale(candidate.clamped(to: 0.35...3.5))
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

        isInteracting = true
        scheduleInteractionFallbackEnd(for: kind)
    }

    private func endInteraction(_ kind: InteractionKind) {
        switch kind {
        case .drag:
            isDragging = false
        case .scale:
            isScaling = false
        case .rotation:
            isRotating = false
        }

        if !isDragging && !isScaling && !isRotating {
            activeElement = nil
            isInteracting = false
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

            if !isDragging && !isScaling && !isRotating {
                activeElement = nil
                isInteracting = false
            }
        }
    }
}

private struct StickerDetailShapePath: Shape {
    let kind: StickerDetailShapeKind

    func path(in rect: CGRect) -> Path {
        switch kind {
        case .rectangle:
            return Rectangle().path(in: rect)
        case .circle:
            return Ellipse().path(in: rect)
        case .star:
            var path = Path()
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let outerX = rect.width / 2
            let outerY = rect.height / 2
            let innerRatio: CGFloat = 0.43
            for index in 0..<10 {
                let angle = -CGFloat.pi / 2 + CGFloat(index) * CGFloat.pi / 5
                let radius = index.isMultiple(of: 2) ? CGFloat(1) : innerRatio
                let point = CGPoint(
                    x: center.x + cos(angle) * outerX * radius,
                    y: center.y + sin(angle) * outerY * radius
                )
                if index == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }
            path.closeSubpath()
            return path
        case .heart:
            var path = Path()
            path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.addCurve(
                to: CGPoint(x: rect.minX, y: rect.height * 0.30 + rect.minY),
                control1: CGPoint(x: rect.width * 0.36 + rect.minX, y: rect.height * 0.76 + rect.minY),
                control2: CGPoint(x: rect.minX, y: rect.height * 0.56 + rect.minY)
            )
            path.addCurve(
                to: CGPoint(x: rect.midX, y: rect.height * 0.24 + rect.minY),
                control1: CGPoint(x: rect.minX, y: rect.minY),
                control2: CGPoint(x: rect.width * 0.36 + rect.minX, y: rect.minY)
            )
            path.addCurve(
                to: CGPoint(x: rect.maxX, y: rect.height * 0.30 + rect.minY),
                control1: CGPoint(x: rect.width * 0.64 + rect.minX, y: rect.minY),
                control2: CGPoint(x: rect.maxX, y: rect.minY)
            )
            path.addCurve(
                to: CGPoint(x: rect.midX, y: rect.maxY),
                control1: CGPoint(x: rect.maxX, y: rect.height * 0.56 + rect.minY),
                control2: CGPoint(x: rect.width * 0.64 + rect.minX, y: rect.height * 0.76 + rect.minY)
            )
            path.closeSubpath()
            return path
        }
    }
}

private struct BackgroundCheckerboard: View {
    var body: some View {
        Canvas { context, size in
            let cell: CGFloat = 24
            let rows = Int(ceil(size.height / cell))
            let columns = Int(ceil(size.width / cell))
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(white: 0.90)))
            for row in 0...rows {
                for column in 0...columns where (row + column).isMultiple(of: 2) {
                    context.fill(
                        Path(CGRect(x: CGFloat(column) * cell, y: CGFloat(row) * cell, width: cell, height: cell)),
                        with: .color(Color(white: 0.78))
                    )
                }
            }
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

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
