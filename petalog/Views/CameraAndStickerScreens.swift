//
//  CameraAndStickerScreens.swift
//  petalog
//

import AVFoundation
import SwiftUI
import UIKit

struct CameraScreen: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var camera = CameraService()

    var body: some View {
        NavigationStack {
            ZStack {
                cameraPreview
                    .ignoresSafeArea()

                VStack {
                    cameraTopBar
                    Spacer()
                    cameraBottomBar
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 26)
            }
            .background(Color.black)
            .toolbar(.hidden, for: .navigationBar)
            .toolbar(.hidden, for: .tabBar)
            .onAppear { camera.requestPermissionAndStart() }
            .onDisappear { camera.stop() }
        }
    }

    @ViewBuilder
    private var cameraPreview: some View {
        if let image = camera.capturedImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        } else if camera.permissionState == .authorized {
            DualLensCameraPreview(
                outerSession: camera.session,
                selfieSession: camera.selfieSession,
                isSelfieLensActive: camera.isSelfieLensActive
            )
        } else {
            ZStack {
                PetalogTheme.glassBackground
                VStack(spacing: 14) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 58, weight: .semibold))
                    Text("カメラを許可すると撮影できます")
                        .font(.headline)
                }
                .foregroundStyle(PetalogTheme.text)
            }
        }
    }

    private var cameraTopBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .frame(width: 46, height: 46)
            }
            .foregroundStyle(.white)
            .background(.black.opacity(0.28))
            .clipShape(Circle())
            .overlay { Circle().stroke(.white.opacity(0.28), lineWidth: 1) }

            Spacer()

            Button {
                camera.switchCamera()
            } label: {
                Image(systemName: camera.isSelfieLensActive ? "rectangle.inset.filled.and.person.filled" : "rectangle")
                    .font(.headline)
                    .frame(width: 46, height: 46)
            }
            .foregroundStyle(.white)
            .background(.black.opacity(0.28))
            .clipShape(Circle())
            .overlay { Circle().stroke(.white.opacity(0.28), lineWidth: 1) }
            .disabled(camera.capturedImage != nil || camera.isCapturing)
        }
    }

    @ViewBuilder
    private var cameraBottomBar: some View {
        VStack(spacing: 14) {
            if let message = camera.errorMessage {
                Text(message)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(.black.opacity(0.42))
                    .clipShape(Capsule())
            }

            if let image = camera.capturedImage {
                HStack(spacing: 12) {
                    Button {
                        camera.retake()
                    } label: {
                        Label("撮り直す", systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(SecondaryActionButtonStyle())

                    NavigationLink {
                        StickerCreationScreen(originalImage: image)
                    } label: {
                        Label("ステッカーを作る", systemImage: "scissors")
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                }
            } else if camera.permissionState == .denied {
                EmptyStateView(systemImage: "camera.fill", title: "カメラが使えません", message: "設定アプリでカメラの利用を許可してください。")
            } else {
                Button {
                    camera.capturePhoto()
                } label: {
                    ZStack {
                        Circle()
                            .fill(.white)
                            .frame(width: 78, height: 78)
                            .shadow(color: .black.opacity(0.28), radius: 16, y: 8)
                        Circle()
                            .stroke(Color.black.opacity(0.72), lineWidth: 3)
                            .frame(width: 62, height: 62)
                        if camera.isCapturing {
                            ProgressView()
                                .tint(.black)
                        }
                    }
                }
                .disabled(camera.isCapturing)
                .accessibilityLabel("撮影")
            }
        }
    }
}

private struct DualLensCameraPreview: View {
    let outerSession: AVCaptureSession
    let selfieSession: AVCaptureSession
    let isSelfieLensActive: Bool

    var body: some View {
        GeometryReader { proxy in
            let lensSize = min(proxy.size.width, proxy.size.height) * 0.58

            ZStack {
                CameraPreview(session: outerSession)
                    .overlay {
                        LinearGradient(
                            colors: [.black.opacity(0.08), .clear, .white.opacity(0.08)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }

                if isSelfieLensActive {
                    CameraPreview(session: selfieSession)
                        .frame(width: lensSize, height: lensSize)
                        .clipShape(Circle())
                        .overlay {
                            Circle()
                                .stroke(.white.opacity(0.92), lineWidth: 10)
                                .shadow(color: .white.opacity(0.56), radius: 8)
                        }
                        .overlay {
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            .white.opacity(0.82),
                                            PetalogTheme.glassPink.opacity(0.58),
                                            PetalogTheme.glassMint.opacity(0.42)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 4
                                )
                        }
                        .shadow(color: .black.opacity(0.2), radius: 22, y: 10)
                        .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                }
            }
        }
    }
}

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
                                .foregroundStyle(PetalogTheme.secondaryText)
                            Slider(value: $draft.cropScale, in: 1...3.2)
                        }

                        HStack(spacing: 12) {
                            Image(systemName: "rotate.right")
                                .foregroundStyle(PetalogTheme.secondaryText)
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
                        .textFieldStyle(.roundedBorder)
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
        .background(PetalogTheme.glassBackground)
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
                    .foregroundStyle(PetalogTheme.text)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .overlay { Circle().stroke(PetalogTheme.border, lineWidth: 1) }
                    .padding(8)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(.white.opacity(0.7), lineWidth: 1)
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
            PetalogTheme.glassBackground
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

struct StickerPostScreen: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = StickerPostViewModel()

    let originalImage: UIImage
    let stickerPNG: Data
    let draft: StickerDraft
    @State private var selectedGroup: PetalogGroup?
    @State private var postedGroup: PetalogGroup?
    @State private var didPost = false

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                if let uiImage = UIImage(data: stickerPNG) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 220)
                        .padding(12)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(PetalogTheme.border, lineWidth: 1)
                        }
                } else {
                    EmptyStateView(systemImage: "exclamationmark.triangle.fill", title: "ステッカー生成待ち", message: "戻ってもう一度「完成」を押してください。")
                }

                ControlSection(title: "投稿するグループ") {
                    if appState.groups.isEmpty {
                        EmptyStateView(systemImage: "person.3.fill", title: "投稿先がありません", message: "先にグループを作るか参加してください。")
                    } else {
                        VStack(spacing: 10) {
                            ForEach(appState.groups) { group in
                                Button {
                                    selectedGroup = group
                                } label: {
                                    HStack {
                                        Text(group.icon).font(.title2)
                                        Text(group.name).font(.headline)
                                        Spacer()
                                        if selectedGroup?.id == group.id {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(PetalogTheme.primary)
                                        }
                                    }
                                }
                                .buttonStyle(ListRowButtonStyle())
                            }
                        }
                    }
                }

                Button {
                    Task { await upload() }
                } label: {
                    if viewModel.isUploading {
                        ProgressView("Firebase Storageに保存中")
                    } else {
                        Label("絵日記に追加する", systemImage: "plus.circle.fill")
                    }
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .disabled(selectedGroup == nil || viewModel.isUploading || stickerPNG.isEmpty)

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                if let postedGroup, didPost {
                    NavigationLink("今日の絵日記を見る") {
                        DiaryScreen(group: postedGroup)
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                }
            }
            .padding(20)
        }
        .background(PetalogTheme.glassBackground)
        .navigationTitle("投稿")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            selectedGroup = selectedGroup ?? appState.groups.first
        }
    }

    private func upload() async {
        guard let user = appState.currentUser, let group = selectedGroup else { return }
        let post = await viewModel.upload(originalImage: originalImage, stickerPNG: stickerPNG, draft: draft, group: group, user: user)
        if post != nil {
            postedGroup = group
            didPost = true
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
