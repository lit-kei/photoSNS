//
//  StickerShapes.swift
//  petanko
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
    var customOutlineColor: Color = .white

    var body: some View {
        StickerMaskShape(shape: shape)
            .stroke(resolvedOutlineColor, style: StrokeStyle(lineWidth: 7, lineCap: .round, dash: decoration == .handDrawn ? [8, 5] : []))
    }

    private var resolvedOutlineColor: Color {
        switch decoration {
        case .whiteOutline: .white
        case .sparkle, .colorfulOutline: customOutlineColor
        case .handDrawn: .black.opacity(0.72)
        case .shadow, .none: .clear
        }
    }
}

private struct HeartShape: Shape {
    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        let rect = CGRect(
            x: rect.midX - side / 2,
            y: rect.midY - side / 2,
            width: side,
            height: side
        ).insetBy(dx: side * 0.05, dy: side * 0.04)
        var path = Path()
        let width = rect.width
        let height = rect.height
        let bottom = CGPoint(x: rect.midX, y: rect.minY + height * 0.96)

        path.move(to: bottom)
        path.addCurve(
            to: CGPoint(x: rect.minX + width * 0.05, y: rect.minY + height * 0.35),
            control1: CGPoint(x: rect.minX + width * 0.23, y: rect.minY + height * 0.78),
            control2: CGPoint(x: rect.minX + width * 0.05, y: rect.minY + height * 0.62)
        )
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.minY + height * 0.27),
            control1: CGPoint(x: rect.minX + width * 0.05, y: rect.minY + height * 0.09),
            control2: CGPoint(x: rect.minX + width * 0.34, y: rect.minY + height * 0.02)
        )
        path.addCurve(
            to: CGPoint(x: rect.maxX - width * 0.05, y: rect.minY + height * 0.35),
            control1: CGPoint(x: rect.maxX - width * 0.34, y: rect.minY + height * 0.02),
            control2: CGPoint(x: rect.maxX - width * 0.05, y: rect.minY + height * 0.09)
        )
        path.addCurve(
            to: bottom,
            control1: CGPoint(x: rect.maxX - width * 0.05, y: rect.minY + height * 0.62),
            control2: CGPoint(x: rect.maxX - width * 0.23, y: rect.minY + height * 0.78)
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
        let point: (CGFloat, CGFloat) -> CGPoint = { x, y in
            CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y)
        }

        path.move(to: point(0.18, 0.76))
        path.addCurve(to: point(0.08, 0.58), control1: point(0.10, 0.74), control2: point(0.06, 0.67))
        path.addCurve(to: point(0.24, 0.40), control1: point(0.08, 0.48), control2: point(0.14, 0.41))
        path.addCurve(to: point(0.43, 0.27), control1: point(0.28, 0.28), control2: point(0.35, 0.24))
        path.addCurve(to: point(0.68, 0.39), control1: point(0.55, 0.18), control2: point(0.66, 0.26))
        path.addCurve(to: point(0.91, 0.57), control1: point(0.82, 0.36), control2: point(0.91, 0.45))
        path.addCurve(to: point(0.80, 0.76), control1: point(0.93, 0.68), control2: point(0.88, 0.74))
        path.addLine(to: point(0.18, 0.76))
        path.closeSubpath()
        return path
    }
}

private struct FlowerShape: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let points = (0..<12).map { index -> CGPoint in
            let angle = CGFloat(index) * .pi / 6 - .pi / 2
            let radius = (index.isMultiple(of: 2) ? 0.48 : 0.30) * min(rect.width, rect.height)
            return CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
        }

        var path = Path()
        path.move(to: midpoint(points.last!, points[0]))
        for index in points.indices {
            path.addQuadCurve(
                to: midpoint(points[index], points[(index + 1) % points.count]),
                control: points[index]
            )
        }
        path.closeSubpath()
        return path
    }

    private func midpoint(_ first: CGPoint, _ second: CGPoint) -> CGPoint {
        CGPoint(x: (first.x + second.x) / 2, y: (first.y + second.y) / 2)
    }
}
