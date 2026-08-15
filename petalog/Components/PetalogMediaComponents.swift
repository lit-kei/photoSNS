import AVFoundation
import SwiftUI

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.videoPreviewLayer.session = session
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
    @State private var cachedImage: CachedStickerImage?
    @State private var loadedURLString: String?
    @State private var isLoading = false

    var body: some View {
        Group {
            if let cachedImage {
                Image(uiImage: cachedImage.image)
                    .resizable()
                    .scaledToFit()
            } else if isLoading {
                ProgressView()
            } else {
                fallback
            }
        }
        .task(id: urlString) {
            await loadImage()
        }
    }

    private var fallback: some View {
        Image(systemName: fallbackSystemImage)
            .font(.system(size: 42, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppColors.charcoal.opacity(0.82))
    }

    @MainActor
    private func loadImage() async {
        guard let url = URL(string: urlString), !urlString.isEmpty else {
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
            let loadedImage = try await StickerImageCache.shared.image(for: url)
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
                        .foregroundStyle(index.isMultiple(of: 2) ? PetalogTheme.accent : .white)
                        .opacity(pulse)
                        .position(x: x, y: y)
                }
            }
        }
        .allowsHitTesting(false)
    }
}
