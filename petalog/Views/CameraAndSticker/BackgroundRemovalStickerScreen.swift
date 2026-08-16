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
    let originalImage: UIImage

    @StateObject private var viewModel = BackgroundRemovalViewModel()
    @State private var draft = StickerDraft(creationMode: .backgroundRemoval)
    @State private var extractionAttempt = 0
    @State private var preparedForeground: UIImage?
    @State private var isPreparingPreview = false
    @State private var preparationError: String?
    @State private var generatedPNG: Data?
    @State private var isShowingPostScreen = false
    @State private var isInteracting = false

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
        .background { PetalogMetalBackground() }
        .navigationTitle("背景透過ステッカー")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $isShowingPostScreen) {
            StickerPostScreen(stickerPNG: generatedPNG ?? Data(), draft: draft)
        }
        .task(id: extractionAttempt) {
            await viewModel.extract(from: originalImage)
        }
        .onDisappear {
            preparedForeground = nil
            viewModel.discard()
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

                ControlSection(title: "エフェクト") {
                    HorizontalOptionPicker(options: StickerEffect.allCases, selection: $draft.effect)
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

                    if draft.decoration.supportsBackgroundOutlineColor {
                        ColorPicker("縁取り色", selection: outlineColorBinding, supportsOpacity: false)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppColors.mainText)
                    }
                }

                ControlSection(title: "コメント") {
                    TextField("例: 海きれいだった！", text: $draft.comment)
                        .textFieldStyle(.plain)
                        .metalTextField()
                }

                Button {
                    completeSticker()
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
        .task(id: PreviewPreparationKey(effect: draft.effect, decoration: draft.decoration, outlineColorHex: draft.outlineColorHex)) {
            await preparePreview(from: foreground)
        }
    }

    private var outlineColorBinding: Binding<Color> {
        Binding(
            get: {
                Color(uiColor: UIColor(hex: draft.outlineColorHex) ?? .white)
            },
            set: { color in
                draft.outlineColorHex = UIColor(color).petalogHexString
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
                effect: draft.effect,
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

    private func completeSticker() {
        guard let preparedForeground else { return }
        do {
            draft.creationMode = .backgroundRemoval
            generatedPNG = try BackgroundStickerRenderer.renderPNG(
                preparedForeground: preparedForeground,
                draft: draft
            )
            isShowingPostScreen = true
        } catch {
            preparationError = error.localizedDescription
        }
    }
}

private struct PreviewPreparationKey: Equatable {
    let effect: StickerEffect
    let decoration: StickerDecoration
    let outlineColorHex: String
}

private extension StickerDecoration {
    var supportsBackgroundOutlineColor: Bool {
        switch self {
        case .whiteOutline, .sparkle:
            true
        case .none, .colorfulOutline, .shadow, .handDrawn:
            false
        }
    }
}

private struct BackgroundForegroundPreview: View {
    let image: UIImage
    @Binding var draft: StickerDraft
    @Binding var isInteracting: Bool

    @State private var dragStart: CGSize?
    @State private var scaleStart: Double?
    @State private var rotationStart: Double?
    @State private var liveRotation: Double = 0
    @State private var isDragging = false
    @State private var isMagnifying = false
    @State private var isRotating = false

    var body: some View {
        GeometryReader { proxy in
            let size = BackgroundStickerRenderer.placementSize(
                imageSize: image.size,
                canvasSize: proxy.size,
                scale: draft.foregroundScale
            )
            let displayedRotation = draft.foregroundRotation + liveRotation

            ZStack {
                BackgroundCheckerboard()
                Image(uiImage: image)
                    .resizable()
                    .frame(width: size.width, height: size.height)
                    .rotationEffect(.degrees(displayedRotation))
                    .offset(
                        x: draft.foregroundOffset.width * proxy.size.width,
                        y: draft.foregroundOffset.height * proxy.size.height
                    )
            }
            .contentShape(Rectangle())
            .clipped()
            .highPriorityGesture(dragGesture(canvasSize: proxy.size, rotation: displayedRotation))
            .simultaneousGesture(magnificationGesture(canvasSize: proxy.size, rotation: displayedRotation))
            .simultaneousGesture(rotationGesture(canvasSize: proxy.size))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .stroke(AppColors.border, lineWidth: 0.8)
            }
        }
    }

    private func dragGesture(canvasSize: CGSize, rotation: Double) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                isDragging = true
                updateInteractionState()
                let start = dragStart ?? draft.foregroundOffset
                dragStart = start
                let proposed = CGSize(
                    width: start.width + value.translation.width / max(canvasSize.width, 1),
                    height: start.height + value.translation.height / max(canvasSize.height, 1)
                )
                draft.foregroundOffset = constrained(proposed, canvasSize: canvasSize, rotation: rotation)
            }
            .onEnded { _ in
                dragStart = nil
                isDragging = false
                updateInteractionState()
            }
    }

    private func magnificationGesture(canvasSize: CGSize, rotation: Double) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                isMagnifying = true
                updateInteractionState()
                let start = scaleStart ?? draft.foregroundScale
                scaleStart = start
                draft.foregroundScale = (start * Double(value)).clamped(to: BackgroundStickerRenderer.scaleRange)
                draft.foregroundOffset = constrained(draft.foregroundOffset, canvasSize: canvasSize, rotation: rotation)
            }
            .onEnded { _ in
                scaleStart = nil
                isMagnifying = false
                updateInteractionState()
            }
    }

    private func rotationGesture(canvasSize: CGSize) -> some Gesture {
        RotationGesture()
            .onChanged { value in
                isRotating = true
                updateInteractionState()
                if rotationStart == nil {
                    rotationStart = draft.foregroundRotation
                }
                liveRotation = value.degrees
                draft.foregroundOffset = constrained(
                    draft.foregroundOffset,
                    canvasSize: canvasSize,
                    rotation: (rotationStart ?? 0) + liveRotation
                )
            }
            .onEnded { value in
                draft.foregroundRotation = normalizedAngle((rotationStart ?? draft.foregroundRotation) + value.degrees)
                liveRotation = 0
                rotationStart = nil
                draft.foregroundOffset = constrained(
                    draft.foregroundOffset,
                    canvasSize: canvasSize,
                    rotation: draft.foregroundRotation
                )
                isRotating = false
                updateInteractionState()
            }
    }

    private func constrained(_ offset: CGSize, canvasSize: CGSize, rotation: Double) -> CGSize {
        BackgroundStickerRenderer.constrainedOffset(
            offset,
            imageSize: image.size,
            canvasSize: canvasSize,
            scale: draft.foregroundScale,
            rotation: rotation
        )
    }

    private func updateInteractionState() {
        isInteracting = isDragging || isMagnifying || isRotating
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
