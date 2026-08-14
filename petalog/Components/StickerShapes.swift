//
//  StickerShapes.swift
//  petalog
//

import SwiftUI

struct StickerMaskShape: Shape {
    let shape: StickerShapeOption

    func path(in rect: CGRect) -> Path {
        switch shape {
        case .circle:
            Path(ellipseIn: rect)
        case .square:
            Path(roundedRect: rect, cornerRadius: 8)
        case .heart:
            HeartShape().path(in: rect)
        case .star:
            StarShape().path(in: rect)
        case .cloud:
            CloudShape().path(in: rect)
        case .flower:
            FlowerShape().path(in: rect)
        }
    }
}

struct StickerOutline: View {
    let shape: StickerShapeOption
    let decoration: StickerDecoration

    var body: some View {
        StickerMaskShape(shape: shape)
            .stroke(outlineColor, style: StrokeStyle(lineWidth: 7, lineCap: .round, dash: decoration == .handDrawn ? [8, 5] : []))
            .shadow(color: decoration == .shadow ? .black.opacity(0.22) : .clear, radius: 12, y: 8)
    }

    private var outlineColor: Color {
        switch decoration {
        case .whiteOutline, .sparkle: .white
        case .colorfulOutline: .pink
        case .handDrawn: .black.opacity(0.72)
        case .shadow, .none: .clear
        }
    }
}

private struct HeartShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height

        path.move(to: CGPoint(x: rect.midX, y: rect.maxY * 0.9))
        path.addCurve(to: CGPoint(x: rect.minX + width * 0.08, y: rect.minY + height * 0.36), control1: CGPoint(x: rect.minX + width * 0.18, y: rect.minY + height * 0.72), control2: CGPoint(x: rect.minX, y: rect.minY + height * 0.52))
        path.addCurve(to: CGPoint(x: rect.midX, y: rect.minY + height * 0.26), control1: CGPoint(x: rect.minX + width * 0.08, y: rect.minY + height * 0.06), control2: CGPoint(x: rect.minX + width * 0.38, y: rect.minY + height * 0.08))
        path.addCurve(to: CGPoint(x: rect.maxX - width * 0.08, y: rect.minY + height * 0.36), control1: CGPoint(x: rect.maxX - width * 0.38, y: rect.minY + height * 0.08), control2: CGPoint(x: rect.maxX - width * 0.08, y: rect.minY + height * 0.06))
        path.addCurve(to: CGPoint(x: rect.midX, y: rect.maxY * 0.9), control1: CGPoint(x: rect.maxX, y: rect.minY + height * 0.52), control2: CGPoint(x: rect.maxX - width * 0.18, y: rect.minY + height * 0.72))
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
            let point = CGPoint(x: center.x + CGFloat(cos(angle)) * radius, y: center.y + CGFloat(sin(angle)) * radius)
            pointIndex == 0 ? path.move(to: point) : path.addLine(to: point)
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
