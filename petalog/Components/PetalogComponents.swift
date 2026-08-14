//
//  PetalogComponents.swift
//  petalog
//

import AVFoundation
import SwiftUI

struct PrimaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .background(PetalogTheme.primary.opacity(configuration.isPressed ? 0.78 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct SecondaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(PetalogTheme.text)
            .padding(.vertical, 14)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity)
            .background(.white.opacity(configuration.isPressed ? 0.7 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(PetalogTheme.border, lineWidth: 1)
            }
    }
}

struct ListRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(PetalogTheme.text)
            .padding(12)
            .background(.white.opacity(configuration.isPressed ? 0.72 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(PetalogTheme.border, lineWidth: 1)
            }
    }
}

struct ControlSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(PetalogTheme.text)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct HorizontalOptionPicker<Option: PetalogOption>: View {
    let options: [Option]
    @Binding var selection: Option

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(options) { option in
                    Button {
                        selection = option
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: option.systemImage)
                                .font(.title3)
                            Text(option.title)
                                .font(.caption.weight(.semibold))
                        }
                        .frame(width: 76, height: 70)
                    }
                    .buttonStyle(OptionButtonStyle(isSelected: option.id == selection.id))
                }
            }
        }
    }
}

private struct OptionButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isSelected ? .white : PetalogTheme.text)
            .background(isSelected ? PetalogTheme.primary : .white)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? PetalogTheme.primary : PetalogTheme.border, lineWidth: 1)
            }
            .opacity(configuration.isPressed ? 0.78 : 1)
    }
}

struct MemberAvatarStack: View {
    let avatars: [String]

    var body: some View {
        HStack(spacing: -8) {
            ForEach(Array(avatars.prefix(4).enumerated()), id: \.offset) { _, avatar in
                Text(avatar)
                    .font(.title3)
                    .frame(width: 34, height: 34)
                    .background(.white)
                    .clipShape(Circle())
                    .overlay { Circle().stroke(.white, lineWidth: 2) }
            }
        }
    }
}

struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(PetalogTheme.primary)
            Text(title)
                .font(.headline)
                .foregroundStyle(PetalogTheme.text)
            Text(message)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(PetalogTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(22)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

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
            .background(PetalogTheme.primary.opacity(0.75))
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
                        .foregroundStyle(index.isMultiple(of: 2) ? .yellow : .white)
                        .opacity(pulse)
                        .position(x: x, y: y)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

struct DiaryBackgroundView: View {
    let background: ScrapbookBackground

    var body: some View {
        switch background {
        case .notebook:
            NotebookBackground()
        case .grid:
            GridPaperBackground()
        case .craft:
            PetalogTheme.craft
        case .sky:
            PetalogTheme.sky
        case .pink:
            PetalogTheme.pinkPaper
        case .stars:
            LinearGradient(colors: [Color(red: 0.06, green: 0.09, blue: 0.18), Color(red: 0.16, green: 0.19, blue: 0.36)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .check:
            CheckBackground()
        }
    }
}

private struct NotebookBackground: View {
    var body: some View {
        ZStack {
            Color.white
            VStack(spacing: 24) {
                ForEach(0..<18, id: \.self) { _ in
                    Rectangle()
                        .fill(Color(red: 0.88, green: 0.93, blue: 0.98))
                        .frame(height: 1)
                }
            }
            .padding(.vertical, 16)
        }
    }
}

private struct GridPaperBackground: View {
    var body: some View {
        ZStack {
            Color.white
            GridPattern()
                .stroke(Color(red: 0.88, green: 0.92, blue: 0.95), lineWidth: 1)
        }
    }
}

private struct CheckBackground: View {
    var body: some View {
        ZStack {
            Color(red: 1.0, green: 0.97, blue: 0.98)
            GridPattern(cellSize: 36)
                .stroke(Color(red: 0.98, green: 0.72, blue: 0.78).opacity(0.55), lineWidth: 12)
        }
    }
}

private struct GridPattern: Shape {
    var cellSize: CGFloat = 22

    func path(in rect: CGRect) -> Path {
        var path = Path()
        stride(from: rect.minX, through: rect.maxX, by: cellSize).forEach { x in
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.addLine(to: CGPoint(x: x, y: rect.maxY))
        }
        stride(from: rect.minY, through: rect.maxY, by: cellSize).forEach { y in
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
        }
        return path
    }
}
