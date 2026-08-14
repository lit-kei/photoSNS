//
//  CameraAndStickerScreens.swift
//  petalog
//

import SwiftUI
import UIKit

struct CameraScreen: View {
    @StateObject private var camera = CameraService()

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                ZStack {
                    if let image = camera.capturedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else if camera.permissionState == .authorized {
                        CameraPreview(session: camera.session)
                    } else {
                        VStack(spacing: 14) {
                            Image(systemName: "camera.viewfinder")
                                .font(.system(size: 58, weight: .semibold))
                            Text("カメラを許可すると撮影できます")
                                .font(.headline)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(red: 0.08, green: 0.13, blue: 0.17))
                    }
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(3 / 4, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    Button {
                        camera.switchCamera()
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath.camera.fill")
                            .font(.title3)
                            .frame(width: 44, height: 44)
                    }
                    .foregroundStyle(.white)
                    .background(.black.opacity(0.22))
                    .clipShape(Circle())
                    .padding(14)
                    .disabled(camera.capturedImage != nil)
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
                            Circle().fill(.white).frame(width: 74, height: 74)
                            Circle().stroke(PetalogTheme.primary, lineWidth: 5).frame(width: 64, height: 64)
                        }
                    }
                    .accessibilityLabel("撮影")
                }

                if let message = camera.errorMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(PetalogTheme.background)
            .navigationTitle("カメラ")
            .onAppear { camera.requestPermissionAndStart() }
            .onDisappear { camera.stop() }
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
        .background(PetalogTheme.background)
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

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .overlay(.black.opacity(0.18))

                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width * 0.62, height: proxy.size.width * 0.62)
                    .clipShape(StickerMaskShape(shape: draft.shape))
                    .overlay { StickerOutline(shape: draft.shape, decoration: draft.decoration) }
                    .overlay {
                        if draft.decoration == .sparkle {
                            SparkleOverlay()
                        }
                    }
                    .scaleEffect(draft.scale)
                    .rotationEffect(.degrees(draft.rotation))
                    .offset(draft.offset)
                    .gesture(
                        DragGesture().onChanged { value in
                            draft.offset = value.translation
                        }
                    )
                    .simultaneousGesture(
                        MagnificationGesture().onChanged { value in
                            draft.scale = min(1.8, max(0.55, value))
                        }
                    )
                    .simultaneousGesture(
                        RotationGesture().onChanged { value in
                            draft.rotation = value.degrees
                        }
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
                        ProgressView()
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
        .background(PetalogTheme.background)
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
