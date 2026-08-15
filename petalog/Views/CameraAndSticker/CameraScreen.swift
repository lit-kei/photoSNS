import SwiftUI
import UIKit

struct CameraScreen: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var camera = CameraService()
    var onClose: (() -> Void)? = nil

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
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
        } else if camera.permissionState == .authorized {
            CameraPreview(session: camera.session)
        } else {
            cameraPermissionView
        }
    }

    private var cameraPermissionView: some View {
        ZStack {
            PetalogMetalBackground()
            VStack(spacing: 18) {
                Image(systemName: "camera")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(AppColors.mainText)
                    .frame(width: 76, height: 76)
                    .background {
                        Circle()
                            .fill(AppColors.surface.opacity(0.94))
                    }
                    .overlay {
                        Circle().stroke(AppColors.border, lineWidth: 0.8)
                    }

                VStack(spacing: 8) {
                    Text("カメラへのアクセスが必要です")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(AppColors.mainText)
                    Text("写真を撮影するため、設定からカメラを許可してください。")
                        .font(.system(size: 14))
                        .foregroundStyle(AppColors.secondaryText)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }

                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label("設定を開く", systemImage: "gearshape")
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .frame(maxWidth: 240)
                .opacity(camera.permissionState == .denied ? 1 : 0)
                .disabled(camera.permissionState != .denied)
            }
            .padding(.horizontal, 32)
        }
    }

    private var cameraTopBar: some View {
        HStack {
            Button {
                if let onClose {
                    onClose()
                } else {
                    dismiss()
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 42, height: 42)
            }
            .foregroundStyle(camera.permissionState == .authorized ? .white : AppColors.mainText)
            .background(camera.permissionState == .authorized ? .black.opacity(0.24) : AppColors.surface.opacity(0.94))
            .clipShape(Circle())
            .overlay { Circle().stroke((camera.permissionState == .authorized ? Color.white.opacity(0.26) : AppColors.border), lineWidth: 0.8) }

            Spacer()

            if let image = camera.capturedImage {
                HStack(spacing: 10) {
                    retakeIconButton
                    stickerCreationIconLink(image: image)
                }
            } else if camera.permissionState == .authorized {
                Button {
                    camera.switchCamera()
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath.camera.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 42, height: 42)
                }
                .disabled(!camera.canSwitchCamera)
                .foregroundStyle(.white)
                .background(.black.opacity(0.24))
                .clipShape(Circle())
                .overlay { Circle().stroke(Color.white.opacity(0.26), lineWidth: 0.8) }
                .accessibilityLabel(camera.isUsingFrontCamera ? "背面カメラに切り替える" : "前面カメラに切り替える")
            }
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

            if camera.capturedImage != nil {
                EmptyView()
            } else if camera.permissionState == .denied {
                EmptyView()
            } else if camera.permissionState == .unknown {
                ProgressView()
                    .tint(AppColors.mainText)
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
        .frame(maxWidth: .infinity)
    }

    private var retakeIconButton: some View {
        Button {
            camera.retake()
        } label: {
            Image(systemName: "arrow.counterclockwise")
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 42, height: 42)
        }
        .foregroundStyle(.white)
        .background(.black.opacity(0.28))
        .clipShape(Circle())
        .overlay { Circle().stroke(Color.white.opacity(0.26), lineWidth: 0.8) }
        .accessibilityLabel("撮り直す")
    }

    private func stickerCreationIconLink(image: UIImage) -> some View {
        NavigationLink {
            StickerCreationModeScreen(originalImage: image)
        } label: {
            Image(systemName: "scissors")
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 42, height: 42)
        }
        .foregroundStyle(.white)
        .background(
            LinearGradient(
                colors: [AppColors.charcoal, AppColors.darkSilver],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(Circle())
        .overlay { Circle().stroke(Color.white.opacity(0.28), lineWidth: 0.8) }
        .accessibilityLabel("ステッカーを作る")
    }
}
