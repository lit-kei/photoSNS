import AVFoundation
import SwiftUI

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
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

    var body: some View {
        if let url = URL(string: urlString), !urlString.isEmpty {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                case .failure:
                    fallback
                case .empty:
                    ProgressView()
                @unknown default:
                    fallback
                }
            }
        } else {
            fallback
        }
    }

    private var fallback: some View {
        Image(systemName: fallbackSystemImage)
            .font(.system(size: 42, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppColors.charcoal.opacity(0.82))
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
