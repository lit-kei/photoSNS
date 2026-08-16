import AVFoundation
import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit

struct MyQRCodeSheet: View {
    let playerId: String
    let onScan: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var isShowingScanner = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("My QRコード")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(AppColors.mainText)
                        Text("友達に読み取ってもらうと、プロフィールを見つけてもらえます。")
                            .font(.system(size: 14))
                            .foregroundStyle(AppColors.secondaryText)
                            .lineSpacing(3)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    MetalCard(padding: 18) {
                        VStack(spacing: 18) {
                            PlayerQRCodeView(payload: playerId)
                                .frame(width: 210, height: 210)
                                .padding(18)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                        .stroke(AppColors.border, lineWidth: 0.8)
                                }

                            VStack(spacing: 6) {
                                Text("ユーザーID")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(AppColors.secondaryText)
                                Text(playerId)
                                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(AppColors.mainText)
                                    .multilineTextAlignment(.center)
                                    .textSelection(.enabled)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }

                    Button {
                        isShowingScanner = true
                    } label: {
                        Label("QRコードを読み取る", systemImage: "qrcode.viewfinder")
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.top, AppSpacing.screenTop)
                .padding(.bottom, AppSpacing.section)
            }
            .background {
                PetalogMetalBackground()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(AppColors.mainText)
                    .frame(width: 38, height: 38)
                    .background(AppColors.surface.opacity(0.94), in: Circle())
                    .overlay {
                        Circle().stroke(AppColors.border, lineWidth: 0.8)
                    }
                    .accessibilityLabel("閉じる")
                }
            }
            .sheet(isPresented: $isShowingScanner) {
                PlayerQRScannerSheet { scannedId in
                    isShowingScanner = false
                    dismiss()
                    onScan(scannedId)
                }
            }
        }
    }
}

struct PlayerQRCodeView: View {
    let payload: String
    private let context = CIContext()
    private let filter = CIFilter.qrCodeGenerator()

    var body: some View {
        if let image = makeImage() {
            Image(uiImage: image)
                .resizable()
                .interpolation(.none)
                .scaledToFit()
        } else {
            Image(systemName: "qrcode")
                .font(.system(size: 80))
                .foregroundStyle(AppColors.mainText)
        }
    }

    private func makeImage() -> UIImage? {
        filter.message = Data(payload.utf8)
        guard let outputImage = filter.outputImage,
              let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

struct PlayerQRScannerSheet: View {
    let onScan: (String) -> Void

    var body: some View {
        PlayerQRScannerView(onScan: onScan)
            .ignoresSafeArea()
    }
}

private struct PlayerQRScannerView: UIViewControllerRepresentable {
    let onScan: (String) -> Void

    func makeUIViewController(context: Context) -> PlayerQRScannerViewController {
        let controller = PlayerQRScannerViewController()
        controller.onScan = onScan
        return controller
    }

    func updateUIViewController(_ uiViewController: PlayerQRScannerViewController, context: Context) {}
}

private final class PlayerQRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onScan: ((String) -> Void)?
    private let session = AVCaptureSession()
    private let previewLayer = AVCaptureVideoPreviewLayer()
    private let dimLayer = CAShapeLayer()
    private let cornerLayer = CAShapeLayer()
    private let guideLabel = UILabel()
    private let closeButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureCamera()
        configureOverlay()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = view.bounds
        updateGuideFrame()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        session.stopRunning()
    }

    private func configureCamera() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        output.metadataObjectTypes = [.qr]

        previewLayer.session = session
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.insertSublayer(previewLayer, at: 0)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }

    private func configureOverlay() {
        dimLayer.fillRule = .evenOdd
        view.layer.addSublayer(dimLayer)

        cornerLayer.fillColor = UIColor.clear.cgColor
        cornerLayer.strokeColor = UIColor.white.cgColor
        cornerLayer.lineWidth = 5
        cornerLayer.lineCap = .round
        cornerLayer.lineJoin = .round
        view.layer.addSublayer(cornerLayer)

        guideLabel.text = "QRコードを枠内に合わせてください"
        guideLabel.textColor = .white
        guideLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        guideLabel.textAlignment = .center
        guideLabel.numberOfLines = 2
        guideLabel.backgroundColor = UIColor.black.withAlphaComponent(0.36)
        guideLabel.layer.cornerRadius = 14
        guideLabel.clipsToBounds = true
        view.addSubview(guideLabel)

        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.tintColor = .white
        closeButton.backgroundColor = UIColor.black.withAlphaComponent(0.42)
        closeButton.layer.cornerRadius = 20
        closeButton.layer.borderWidth = 1
        closeButton.layer.borderColor = UIColor.white.withAlphaComponent(0.35).cgColor
        closeButton.addTarget(self, action: #selector(close), for: .touchUpInside)
        view.addSubview(closeButton)
    }

    private func updateGuideFrame() {
        let side = min(view.bounds.width - 72, 284)
        let scanRect = CGRect(
            x: (view.bounds.width - side) / 2,
            y: (view.bounds.height - side) / 2 - 24,
            width: side,
            height: side
        )

        let path = UIBezierPath(rect: view.bounds)
        path.append(UIBezierPath(roundedRect: scanRect, cornerRadius: 24))
        dimLayer.path = path.cgPath
        dimLayer.fillColor = UIColor.black.withAlphaComponent(0.46).cgColor

        let cornerPath = UIBezierPath()
        let length: CGFloat = 42
        addCorner(to: cornerPath, origin: scanRect.origin, x: 1, y: 1, length: length)
        addCorner(to: cornerPath, origin: CGPoint(x: scanRect.maxX, y: scanRect.minY), x: -1, y: 1, length: length)
        addCorner(to: cornerPath, origin: CGPoint(x: scanRect.minX, y: scanRect.maxY), x: 1, y: -1, length: length)
        addCorner(to: cornerPath, origin: CGPoint(x: scanRect.maxX, y: scanRect.maxY), x: -1, y: -1, length: length)
        cornerLayer.path = cornerPath.cgPath

        guideLabel.frame = CGRect(
            x: 32,
            y: scanRect.maxY + 28,
            width: view.bounds.width - 64,
            height: 48
        )
        closeButton.frame = CGRect(x: view.safeAreaInsets.left + 18, y: view.safeAreaInsets.top + 12, width: 40, height: 40)
    }

    private func addCorner(to path: UIBezierPath, origin: CGPoint, x: CGFloat, y: CGFloat, length: CGFloat) {
        path.move(to: origin)
        path.addLine(to: CGPoint(x: origin.x + x * length, y: origin.y))
        path.move(to: origin)
        path.addLine(to: CGPoint(x: origin.x, y: origin.y + y * length))
    }

    @objc private func close() {
        dismiss(animated: true)
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = object.stringValue else { return }
        session.stopRunning()
        onScan?(value)
    }
}
