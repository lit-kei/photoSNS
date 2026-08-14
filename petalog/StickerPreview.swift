//
//  StickerPreview.swift
//  petalog
//
//  Created by Codex on 2026/08/14.
//

import SwiftUI

struct StickerPreview: View {
    let sticker: ScrapbookSticker
    let size: CGFloat
    var showsAuthor = true

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ZStack {
                stickerShapeFill
                    .frame(width: size, height: size)
                    .shadow(
                        color: sticker.decoration == .shadow ? .black.opacity(0.24) : .clear,
                        radius: 12,
                        x: 0,
                        y: 8
                    )

                Image(systemName: sticker.symbolName)
                    .font(.system(size: size * 0.36, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.16), radius: 6, y: 3)
            }
            .overlay {
                stickerOutline
            }
            .overlay {
                if sticker.decoration == .sparkle {
                    SparkleOverlay()
                        .frame(width: size * 1.18, height: size * 1.18)
                }
            }

            if showsAuthor {
                Text(sticker.author.avatar)
                    .font(.system(size: size * 0.22))
                    .frame(width: size * 0.31, height: size * 0.31)
                    .background(.white)
                    .clipShape(Circle())
                    .overlay {
                        Circle().stroke(.white, lineWidth: 2)
                    }
                    .offset(x: size * 0.02, y: size * 0.02)
            }
        }
        .frame(width: size * 1.22, height: size * 1.22)
        .accessibilityLabel(sticker.title)
    }

    @ViewBuilder
    private var stickerShapeFill: some View {
        let fill = ZStack {
            LinearGradient(
                colors: [sticker.tint.opacity(0.95), sticker.tint.opacity(0.55), .white.opacity(0.16)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .fill(.white.opacity(0.22))
                .frame(width: size * 0.56, height: size * 0.56)
                .offset(x: -size * 0.22, y: -size * 0.22)
        }

        switch sticker.shape {
        case .circle:
            fill.clipShape(Circle())
        case .square:
            fill.clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        case .heart:
            fill.clipShape(HeartShape())
        case .star:
            fill.clipShape(StarShape())
        case .cloud:
            fill.clipShape(CloudShape())
        case .flower:
            fill.clipShape(FlowerShape())
        case .freeform:
            fill.clipShape(FreeformShape())
        }
    }

    @ViewBuilder
    private var stickerOutline: some View {
        let lineWidth = max(4, size * 0.06)
        let color: Color = switch sticker.decoration {
        case .whiteOutline, .sparkle: .white
        case .colorfulOutline: .pink
        case .handDrawn: .black.opacity(0.7)
        case .shadow, .none: .clear
        }

        switch sticker.shape {
        case .circle:
            Circle().stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, dash: sticker.decoration == .handDrawn ? [8, 5] : []))
                .frame(width: size, height: size)
        case .square:
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, dash: sticker.decoration == .handDrawn ? [8, 5] : []))
                .frame(width: size, height: size)
        case .heart:
            HeartShape().stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, dash: sticker.decoration == .handDrawn ? [8, 5] : []))
                .frame(width: size, height: size)
        case .star:
            StarShape().stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, dash: sticker.decoration == .handDrawn ? [8, 5] : []))
                .frame(width: size, height: size)
        case .cloud:
            CloudShape().stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, dash: sticker.decoration == .handDrawn ? [8, 5] : []))
                .frame(width: size, height: size)
        case .flower:
            FlowerShape().stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, dash: sticker.decoration == .handDrawn ? [8, 5] : []))
                .frame(width: size, height: size)
        case .freeform:
            FreeformShape().stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, dash: sticker.decoration == .handDrawn ? [8, 5] : []))
                .frame(width: size, height: size)
        }
    }
}

private struct SparkleOverlay: View {
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

private struct HeartShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height

        path.move(to: CGPoint(x: rect.midX, y: rect.maxY * 0.9))
        path.addCurve(
            to: CGPoint(x: rect.minX + width * 0.08, y: rect.minY + height * 0.36),
            control1: CGPoint(x: rect.minX + width * 0.18, y: rect.minY + height * 0.72),
            control2: CGPoint(x: rect.minX, y: rect.minY + height * 0.52)
        )
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.minY + height * 0.26),
            control1: CGPoint(x: rect.minX + width * 0.08, y: rect.minY + height * 0.06),
            control2: CGPoint(x: rect.minX + width * 0.38, y: rect.minY + height * 0.08)
        )
        path.addCurve(
            to: CGPoint(x: rect.maxX - width * 0.08, y: rect.minY + height * 0.36),
            control1: CGPoint(x: rect.maxX - width * 0.38, y: rect.minY + height * 0.08),
            control2: CGPoint(x: rect.maxX - width * 0.08, y: rect.minY + height * 0.06)
        )
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.maxY * 0.9),
            control1: CGPoint(x: rect.maxX, y: rect.minY + height * 0.52),
            control2: CGPoint(x: rect.maxX - width * 0.18, y: rect.minY + height * 0.72)
        )
        path.closeSubpath()
        return path
    }
}

private struct StarShape: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) * 0.48
        let innerRadius = outerRadius * 0.44
        var path = Path()

        for pointIndex in 0..<10 {
            let radius = pointIndex.isMultiple(of: 2) ? outerRadius : innerRadius
            let angle = Double(pointIndex) * Double.pi / 5 - Double.pi / 2
            let point = CGPoint(
                x: center.x + CGFloat(cos(angle)) * radius,
                y: center.y + CGFloat(sin(angle)) * radius
            )

            if pointIndex == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        path.closeSubpath()
        return path
    }
}

private struct CloudShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addEllipse(in: CGRect(x: rect.minX + rect.width * 0.08, y: rect.minY + rect.height * 0.42, width: rect.width * 0.42, height: rect.height * 0.34))
        path.addEllipse(in: CGRect(x: rect.minX + rect.width * 0.28, y: rect.minY + rect.height * 0.24, width: rect.width * 0.42, height: rect.height * 0.48))
        path.addEllipse(in: CGRect(x: rect.minX + rect.width * 0.54, y: rect.minY + rect.height * 0.36, width: rect.width * 0.38, height: rect.height * 0.36))
        path.addRoundedRect(in: CGRect(x: rect.minX + rect.width * 0.18, y: rect.minY + rect.height * 0.5, width: rect.width * 0.66, height: rect.height * 0.24), cornerSize: CGSize(width: rect.width * 0.12, height: rect.height * 0.12))
        return path
    }
}

private struct FlowerShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let petalWidth = rect.width * 0.42
        let petalHeight = rect.height * 0.42
        let center = CGPoint(x: rect.midX, y: rect.midY)

        for index in 0..<6 {
            let angle = Double(index) * Double.pi / 3
            let x = center.x + CGFloat(cos(angle)) * rect.width * 0.2 - petalWidth / 2
            let y = center.y + CGFloat(sin(angle)) * rect.height * 0.2 - petalHeight / 2
            path.addEllipse(in: CGRect(x: x, y: y, width: petalWidth, height: petalHeight))
        }

        path.addEllipse(in: CGRect(x: rect.midX - rect.width * 0.22, y: rect.midY - rect.height * 0.22, width: rect.width * 0.44, height: rect.height * 0.44))
        return path
    }
}

private struct FreeformShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.18, y: rect.minY + rect.height * 0.22))
        path.addCurve(
            to: CGPoint(x: rect.maxX - rect.width * 0.16, y: rect.minY + rect.height * 0.2),
            control1: CGPoint(x: rect.minX + rect.width * 0.38, y: rect.minY - rect.height * 0.06),
            control2: CGPoint(x: rect.maxX - rect.width * 0.38, y: rect.minY + rect.height * 0.12)
        )
        path.addCurve(
            to: CGPoint(x: rect.maxX - rect.width * 0.12, y: rect.maxY - rect.height * 0.26),
            control1: CGPoint(x: rect.maxX + rect.width * 0.04, y: rect.minY + rect.height * 0.38),
            control2: CGPoint(x: rect.maxX - rect.width * 0.1, y: rect.maxY - rect.height * 0.46)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.24, y: rect.maxY - rect.height * 0.12),
            control1: CGPoint(x: rect.maxX - rect.width * 0.36, y: rect.maxY + rect.height * 0.02),
            control2: CGPoint(x: rect.minX + rect.width * 0.48, y: rect.maxY - rect.height * 0.04)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.18, y: rect.minY + rect.height * 0.22),
            control1: CGPoint(x: rect.minX - rect.width * 0.06, y: rect.maxY - rect.height * 0.28),
            control2: CGPoint(x: rect.minX + rect.width * 0.08, y: rect.minY + rect.height * 0.48)
        )
        path.closeSubpath()
        return path
    }
}
