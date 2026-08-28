import AVFoundation
import SwiftUI

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    let orientation: AVCaptureVideoOrientation

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        // Show the complete sensor image so the visible range matches the
        // photo returned by AVCapturePhotoOutput.
        view.videoPreviewLayer.videoGravity = .resizeAspect
        view.backgroundColor = .black
        applyOrientation(to: view.videoPreviewLayer)
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.videoPreviewLayer.session = session
        applyOrientation(to: uiView.videoPreviewLayer)
    }

    private func applyOrientation(to previewLayer: AVCaptureVideoPreviewLayer) {
        guard let connection = previewLayer.connection,
              connection.isVideoOrientationSupported else {
            return
        }
        connection.videoOrientation = orientation
    }
}

final class PreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}

struct AsyncStickerImage: View {
    let urlString: String
    let fallbackSystemImage: String

    var body: some View {
        RemoteImageView(urlString: urlString, contentMode: .fit) {
            Image(systemName: fallbackSystemImage)
                .font(.system(size: 42, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppColors.charcoal.opacity(0.82))
        }
    }
}

struct RemoteImageView<Placeholder: View>: View {
    let urlString: String?
    let contentMode: ContentMode
    let placeholder: Placeholder
    @State private var cachedImage: CachedRemoteImage?
    @State private var loadedURLString: String?
    @State private var isLoading = false

    init(
        urlString: String?,
        contentMode: ContentMode = .fill,
        @ViewBuilder placeholder: () -> Placeholder
    ) {
        self.urlString = urlString
        self.contentMode = contentMode
        self.placeholder = placeholder()
    }

    var body: some View {
        Group {
            if let cachedImage {
                Image(uiImage: cachedImage.image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else if isLoading {
                placeholder
                    .overlay { ProgressView() }
            } else {
                placeholder
            }
        }
        .task(id: urlString) {
            await loadImage()
        }
    }

    @MainActor
    private func loadImage() async {
        guard let urlString, let url = URL(string: urlString), !urlString.isEmpty else {
            cachedImage = nil
            loadedURLString = nil
            isLoading = false
            return
        }

        if loadedURLString != urlString {
            cachedImage = nil
        }
        guard cachedImage == nil else { return }

        isLoading = true
        defer { isLoading = false }
        do {
            let loadedImage = try await RemoteImageCache.shared.image(for: url)
            guard !Task.isCancelled else { return }
            cachedImage = loadedImage
            loadedURLString = urlString
        } catch {
            guard !Task.isCancelled else { return }
            cachedImage = nil
            loadedURLString = urlString
        }
    }
}

struct SparkleOverlay: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate

            GeometryReader { proxy in
                ForEach(0..<8, id: \.self) { index in
                    let angle = Double(index) / 8.0 * Double.pi * 2
                    let pulse = 0.65 + 0.35 * sin(time * 2.2 + Double(index))
                    let radius = min(proxy.size.width, proxy.size.height) * 0.43
                    let x = proxy.size.width / 2 + cos(angle) * radius
                    let y = proxy.size.height / 2 + sin(angle) * radius

                    Image(systemName: index.isMultiple(of: 2) ? "sparkle" : "star.fill")
                        .font(.system(size: 10 + CGFloat(index % 3) * 3, weight: .bold))
                        .foregroundStyle(index.isMultiple(of: 2) ? PetankoTheme.accent : .white)
                        .opacity(pulse)
                        .position(x: x, y: y)
                }
            }
        }
        .allowsHitTesting(false)
    }
}
