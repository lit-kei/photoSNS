import SwiftUI
import UIKit

struct StickerCreationScreen: View {
    let originalImage: UIImage
    @State private var draft = StickerDraft()
    @State private var generatedPNG: Data?
    @State private var isShowingPostScreen = false
    @State private var renderError: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                StickerComposerPreview(image: originalImage, draft: $draft)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)

                ControlSection(title: "トリミング") {
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            Image(systemName: "plus.magnifyingglass")
                                .foregroundStyle(AppColors.secondaryText)
                            Slider(value: $draft.cropScale, in: 1...3.2)
                        }

                        HStack(spacing: 12) {
                            Image(systemName: "rotate.right")
                                .foregroundStyle(AppColors.secondaryText)
                            Slider(value: $draft.cropRotation, in: -180...180)
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
            .padding(20)
        }
        .background {
            PetalogMetalBackground()
        }
        .navigationTitle("ステッカー作成")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $isShowingPostScreen) {
            StickerPostScreen(originalImage: originalImage, stickerPNG: generatedPNG ?? Data(), draft: draft)
        }
    }
}

private struct StickerComposerPreview: View {
    let image: UIImage
    @Binding var draft: StickerDraft
    @State private var cropDragStart: CGSize?
    @State private var cropScaleStart: Double?
    @State private var cropRotationStart: Double?

    var body: some View {
        GeometryReader { proxy in
            let previewSide = min(proxy.size.width, proxy.size.height)
            let maskSide = previewSide * 0.72
            let cropScale = CGFloat(max(1, draft.cropScale))

            ZStack {
                TransparentStickerPreviewBackground()

                ZStack {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: maskSide * cropScale, height: maskSide * cropScale)
                        .rotationEffect(.degrees(draft.cropRotation))
                        .offset(
                            x: maskSide * draft.cropOffset.width,
                            y: maskSide * draft.cropOffset.height
                        )
                }
                .frame(width: maskSide, height: maskSide)
                .clipShape(StickerMaskShape(shape: draft.shape))
                .overlay { StickerOutline(shape: draft.shape, decoration: draft.decoration) }
                .overlay {
                    if draft.decoration == .sparkle {
                        SparkleOverlay()
                    }
                }
                .contentShape(StickerMaskShape(shape: draft.shape))
                .gesture(cropDragGesture(maskSide: maskSide))
                .simultaneousGesture(cropScaleGesture())
                .simultaneousGesture(cropRotationGesture())
                .shadow(color: .black.opacity(0.16), radius: 18, y: 8)
                .overlay(alignment: .bottomTrailing) {
                    Button {
                        draft.cropScale = 1
                        draft.cropRotation = 0
                        draft.cropOffset = .zero
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
    }

    private func cropDragGesture(maskSide: CGFloat) -> some Gesture {
        DragGesture()
            .onChanged { value in
                let start = cropDragStart ?? draft.cropOffset
                cropDragStart = start
                draft.cropOffset = CGSize(
                    width: (start.width + value.translation.width / maskSide).clamped(to: -1.15...1.15),
                    height: (start.height + value.translation.height / maskSide).clamped(to: -1.15...1.15)
                )
            }
            .onEnded { _ in
                cropDragStart = nil
            }
    }

    private func cropScaleGesture() -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let start = cropScaleStart ?? draft.cropScale
                cropScaleStart = start
                draft.cropScale = (start * Double(value)).clamped(to: 1...3.2)
            }
            .onEnded { _ in
                cropScaleStart = nil
            }
    }

    private func cropRotationGesture() -> some Gesture {
        RotationGesture()
            .onChanged { value in
                let start = cropRotationStart ?? draft.cropRotation
                cropRotationStart = start
                draft.cropRotation = (start + value.degrees).clamped(to: -180...180)
            }
            .onEnded { _ in
                cropRotationStart = nil
            }
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
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
