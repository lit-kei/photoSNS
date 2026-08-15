import SwiftUI
import UIKit

struct StickerCreationScreen: View {
    let originalImage: UIImage
    @State private var draft = StickerDraft()
    @State private var generatedPNG: Data?
    @State private var isShowingPostScreen = false
    @State private var renderError: String?
    @State private var isInteractingWithCrop = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                StickerComposerPreview(image: originalImage, draft: $draft, isInteracting: $isInteractingWithCrop)
                    .frame(maxWidth: .infinity)
                    .frame(height: min(UIScreen.main.bounds.width - 40, 320))

                ControlSection(title: "トリミング") {
                    VStack(spacing: 10) {
                        Text("写真は固定したまま、フレームをドラッグ・ピンチ・回転できます。")
                            .font(.footnote)
                            .foregroundStyle(AppColors.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 12) {
                            Image(systemName: "crop")
                                .foregroundStyle(AppColors.secondaryText)
                            Slider(
                                value: Binding(
                                    get: { draft.cropScale },
                                    set: { draft.updateCrop(scale: $0) }
                                ),
                                in: 1...2.8
                            )
                        }

                        HStack(spacing: 12) {
                            Image(systemName: "rotate.right")
                                .foregroundStyle(AppColors.secondaryText)
                            Slider(
                                value: Binding(
                                    get: { draft.cropRotation },
                                    set: { draft.updateCrop(rotation: $0) }
                                ),
                                in: -180...180
                            )
                        }
                    }
                }

                ControlSection(title: "切り抜き") {
                    HorizontalOptionPicker(options: StickerShapeOption.allCases, selection: $draft.shape)
                }

                ControlSection(title: "デコレーション") {
                    HorizontalOptionPicker(options: StickerDecoration.allCases, selection: $draft.decoration)
                }

                ControlSection(title: "コメント") {
                    TextField("例: 海きれいだった！", text: $draft.comment)
                        .textFieldStyle(.plain)
                        .metalTextField()
                }

                Button {
                    do {
                        generatedPNG = try StickerRenderer.renderPNG(originalImage: originalImage, draft: draft)
                        isShowingPostScreen = true
                    } catch {
                        renderError = error.localizedDescription
                    }
                } label: {
                    Label("完成", systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(PrimaryActionButtonStyle())

                if let renderError {
                    Text(renderError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 28)
        }
        .scrollDisabled(isInteractingWithCrop)
        .background {
            PetalogMetalBackground()
        }
        .navigationTitle("ステッカー作成")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $isShowingPostScreen) {
            StickerPostScreen(stickerPNG: generatedPNG ?? Data(), draft: draft)
        }
    }
}

private struct StickerComposerPreview: View {
    let image: UIImage
    @Binding var draft: StickerDraft
    @Binding var isInteracting: Bool
    @State private var cropDragStart: CGSize?
    @State private var cropScaleStart: Double?
    @State private var cropRotationStart: Double?
    @State private var isDragging = false
    @State private var isMagnifying = false
    @State private var isRotating = false

    var body: some View {
        GeometryReader { proxy in
            let previewSide = min(proxy.size.width, proxy.size.height)
            let maskSide = previewSide * 0.72
            let cropScale = CGFloat(max(1, draft.cropScale))
            let frameSide = maskSide / cropScale
            let frameOffset = displayedFrameOffset(maskSide: maskSide, cropScale: cropScale)

            ZStack {
                TransparentStickerPreviewBackground()

                ZStack {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: maskSide, height: maskSide)
                        .clipped()

                    ZStack {
                        Color.black.opacity(0.38)
                        StickerMaskShape(shape: draft.shape)
                            .fill(.black)
                            .frame(width: frameSide, height: frameSide)
                            .rotationEffect(.degrees(-draft.cropRotation))
                            .offset(frameOffset)
                            .blendMode(.destinationOut)
                    }
                    .compositingGroup()

                    StickerMaskShape(shape: draft.shape)
                        .stroke(.white, style: StrokeStyle(lineWidth: 3, dash: [9, 6]))
                        .frame(width: frameSide, height: frameSide)
                        .rotationEffect(.degrees(-draft.cropRotation))
                        .offset(frameOffset)

                    StickerOutline(shape: draft.shape, decoration: draft.decoration)
                        .frame(width: frameSide, height: frameSide)
                        .rotationEffect(.degrees(-draft.cropRotation))
                        .offset(frameOffset)

                    if draft.decoration == .sparkle {
                        SparkleOverlay()
                            .frame(width: frameSide, height: frameSide)
                            .rotationEffect(.degrees(-draft.cropRotation))
                            .offset(frameOffset)
                    }
                }
                .frame(width: maskSide, height: maskSide)
                .clipped()
                .contentShape(Rectangle())
                .highPriorityGesture(cropDragGesture(maskSide: maskSide))
                .simultaneousGesture(cropScaleGesture())
                .simultaneousGesture(cropRotationGesture())
                .shadow(color: .black.opacity(0.16), radius: 18, y: 8)
                .overlay(alignment: .bottomTrailing) {
                    Button {
                        draft.resetCrop()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.headline)
                            .frame(width: 42, height: 42)
                    }
                    .foregroundStyle(AppColors.mainText)
                    .background(AppColors.surface.opacity(0.94))
                    .clipShape(Circle())
                    .overlay { Circle().stroke(AppColors.border, lineWidth: 0.8) }
                    .padding(8)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .stroke(AppColors.border, lineWidth: 0.8)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func cropDragGesture(maskSide: CGFloat) -> some Gesture {
        DragGesture()
            .onChanged { value in
                guard maskSide.isFinite, maskSide > 1 else { return }
                isDragging = true
                updateInteractionState()
                let start = cropDragStart ?? draft.cropOffset
                cropDragStart = start
                let scale = CGFloat(max(1, draft.cropScale))
                draft.updateCrop(
                    offset: CGSize(
                        width: start.width - value.translation.width * scale / maskSide,
                        height: start.height - value.translation.height * scale / maskSide
                    )
                )
            }
            .onEnded { _ in
                cropDragStart = nil
                isDragging = false
                updateInteractionState()
            }
    }

    private func cropScaleGesture() -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                isMagnifying = true
                updateInteractionState()
                let start = cropScaleStart ?? draft.cropScale
                cropScaleStart = start
                draft.updateCrop(scale: start / Double(value))
            }
            .onEnded { _ in
                cropScaleStart = nil
                isMagnifying = false
                updateInteractionState()
            }
    }

    private func cropRotationGesture() -> some Gesture {
        RotationGesture()
            .onChanged { value in
                isRotating = true
                updateInteractionState()
                let start = cropRotationStart ?? draft.cropRotation
                cropRotationStart = start
                draft.updateCrop(rotation: start - value.degrees)
            }
            .onEnded { _ in
                cropRotationStart = nil
                isRotating = false
                updateInteractionState()
            }
    }

    private func displayedFrameOffset(maskSide: CGFloat, cropScale: CGFloat) -> CGSize {
        guard maskSide.isFinite, cropScale.isFinite, cropScale > 0 else { return .zero }
        return CGSize(
            width: -maskSide * draft.cropOffset.width / cropScale,
            height: -maskSide * draft.cropOffset.height / cropScale
        )
    }

    private func updateInteractionState() {
        isInteracting = isDragging || isMagnifying || isRotating
    }
}

private extension StickerDraft {
    mutating func updateCrop(scale: Double? = nil, rotation: Double? = nil, offset: CGSize? = nil) {
        let proposedScale = scale ?? cropScale
        let proposedRotation = rotation ?? cropRotation

        cropScale = (proposedScale.isFinite ? proposedScale : 1).clamped(to: 1...2.8)
        cropRotation = (proposedRotation.isFinite ? proposedRotation : 0).clamped(to: -180...180)

        let proposedOffset = offset ?? cropOffset
        let limit = cropOffsetLimit
        cropOffset = CGSize(
            width: proposedOffset.width.finiteOrZero.clamped(to: -limit...limit),
            height: proposedOffset.height.finiteOrZero.clamped(to: -limit...limit)
        )
    }

    mutating func resetCrop() {
        updateCrop(scale: 1, rotation: 0, offset: .zero)
    }

    private var cropOffsetLimit: CGFloat {
        let radians = CGFloat(cropRotation) * .pi / 180
        let rotatedExtent = abs(cos(radians)) + abs(sin(radians))
        return max(0, (CGFloat(cropScale) - rotatedExtent) / 2)
    }
}

private struct TransparentStickerPreviewBackground: View {
    var body: some View {
        ZStack {
            PetalogMetalBackground()
            Canvas { context, size in
                let cell: CGFloat = 26
                let rows = Int(ceil(size.height / cell))
                let columns = Int(ceil(size.width / cell))

                for row in 0...rows {
                    for column in 0...columns where (row + column).isMultiple(of: 2) {
                        let rect = CGRect(x: CGFloat(column) * cell, y: CGFloat(row) * cell, width: cell, height: cell)
                        var path = Path()
                        path.addRect(rect)
                        context.fill(path, with: .color(.white.opacity(0.38)))
                    }
                }
            }
            .opacity(0.56)
        }
    }
}

private extension CGFloat {
    var finiteOrZero: CGFloat {
        isFinite ? self : 0
    }

    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
