//
//  StickerRenderer.swift
//  petalog
//

import SwiftUI
import UIKit

enum StickerRenderer {
    static func renderPNG(originalImage: UIImage, draft: StickerDraft, canvasSize: CGSize = CGSize(width: 512, height: 512)) throws -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let stickerSource = originalImage

        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)
        let image = renderer.image { context in
            UIColor.clear.setFill()
            context.fill(CGRect(origin: .zero, size: canvasSize))

            let baseRect = CGRect(
                x: canvasSize.width * 0.11,
                y: canvasSize.height * 0.11,
                width: canvasSize.width * 0.78,
                height: canvasSize.height * 0.78
            )
            let maskRect = baseRect
            let cropScale = max(1, CGFloat(draft.cropScale))
            let cropRect = maskRect
                .scaledAboutCenter(by: cropScale)
                .offsetBy(
                    dx: maskRect.width * draft.cropOffset.width,
                    dy: maskRect.height * draft.cropOffset.height
                )

            let path = StickerShapePath.path(for: draft.shape, in: maskRect)
            let center = CGPoint(x: maskRect.midX, y: maskRect.midY)

            context.cgContext.saveGState()
            path.addClip()
            context.cgContext.translateBy(x: center.x, y: center.y)
            context.cgContext.rotate(by: CGFloat(draft.cropRotation) * .pi / 180)
            context.cgContext.translateBy(x: -center.x, y: -center.y)
            stickerSource.drawAspectFill(in: cropRect)
            context.cgContext.restoreGState()

            drawDecoration(draft.decoration, around: path, in: context.cgContext)
        }

        guard let data = image.pngData() else {
            throw PetalogError.message("ステッカー画像を書き出せませんでした。")
        }
        return data
    }

    private static func drawDecoration(_ decoration: StickerDecoration, around path: UIBezierPath, in context: CGContext) {
        switch decoration {
        case .whiteOutline, .sparkle:
            UIColor.white.setStroke()
            path.lineWidth = 18
            path.stroke()
        case .colorfulOutline:
            UIColor(red: 0.43, green: 0.45, blue: 0.5, alpha: 1).setStroke()
            path.lineWidth = 18
            path.stroke()
            UIColor(red: 0.86, green: 0.87, blue: 0.9, alpha: 1).setStroke()
            path.lineWidth = 7
            path.stroke()
        case .shadow:
            context.saveGState()
            context.setShadow(offset: CGSize(width: 0, height: 12), blur: 18, color: UIColor.black.withAlphaComponent(0.25).cgColor)
            UIColor.clear.setFill()
            path.fill()
            context.restoreGState()
        case .handDrawn:
            UIColor.black.withAlphaComponent(0.7).setStroke()
            path.lineWidth = 9
            path.setLineDash([16, 9], count: 2, phase: 0)
            path.stroke()
        case .none:
            break
        }

        guard decoration == .sparkle else { return }
        let bounds = path.bounds.insetBy(dx: -34, dy: -34)
        for index in 0..<10 {
            let angle = CGFloat(index) / 10 * .pi * 2
            let point = CGPoint(
                x: bounds.midX + cos(angle) * bounds.width * 0.45,
                y: bounds.midY + sin(angle) * bounds.height * 0.45
            )
            drawSparkle(at: point, size: index.isMultiple(of: 2) ? 24 : 15)
        }
    }

    private static func drawSparkle(at point: CGPoint, size: CGFloat) {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: point.x, y: point.y - size))
        path.addLine(to: CGPoint(x: point.x + size * 0.23, y: point.y - size * 0.23))
        path.addLine(to: CGPoint(x: point.x + size, y: point.y))
        path.addLine(to: CGPoint(x: point.x + size * 0.23, y: point.y + size * 0.23))
        path.addLine(to: CGPoint(x: point.x, y: point.y + size))
        path.addLine(to: CGPoint(x: point.x - size * 0.23, y: point.y + size * 0.23))
        path.addLine(to: CGPoint(x: point.x - size, y: point.y))
        path.addLine(to: CGPoint(x: point.x - size * 0.23, y: point.y - size * 0.23))
        path.close()
        UIColor(red: 0.78, green: 0.8, blue: 0.84, alpha: 1).setFill()
        path.fill()
    }
}

enum StickerShapePath {
    static func path(for shape: StickerShapeOption, in rect: CGRect) -> UIBezierPath {
        switch shape {
        case .circle:
            return UIBezierPath(ovalIn: rect)
        case .square:
            return UIBezierPath(roundedRect: rect, cornerRadius: 28)
        case .heart:
            return heart(in: rect)
        case .star:
            return star(in: rect)
        case .cloud:
            return cloud(in: rect)
        case .flower:
            return flower(in: rect)
        }
    }

    private static func heart(in rect: CGRect) -> UIBezierPath {
        let side = min(rect.width, rect.height)
        let rect = CGRect(
            x: rect.midX - side / 2,
            y: rect.midY - side / 2,
            width: side,
            height: side
        ).insetBy(dx: side * 0.05, dy: side * 0.04)
        let width = rect.width
        let height = rect.height
        let bottom = CGPoint(x: rect.midX, y: rect.minY + height * 0.96)
        let path = UIBezierPath()
        path.move(to: bottom)
        path.addCurve(
            to: CGPoint(x: rect.minX + width * 0.05, y: rect.minY + height * 0.35),
            controlPoint1: CGPoint(x: rect.minX + width * 0.23, y: rect.minY + height * 0.78),
            controlPoint2: CGPoint(x: rect.minX + width * 0.05, y: rect.minY + height * 0.62)
        )
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.minY + height * 0.27),
            controlPoint1: CGPoint(x: rect.minX + width * 0.05, y: rect.minY + height * 0.09),
            controlPoint2: CGPoint(x: rect.minX + width * 0.34, y: rect.minY + height * 0.02)
        )
        path.addCurve(
            to: CGPoint(x: rect.maxX - width * 0.05, y: rect.minY + height * 0.35),
            controlPoint1: CGPoint(x: rect.maxX - width * 0.34, y: rect.minY + height * 0.02),
            controlPoint2: CGPoint(x: rect.maxX - width * 0.05, y: rect.minY + height * 0.09)
        )
        path.addCurve(
            to: bottom,
            controlPoint1: CGPoint(x: rect.maxX - width * 0.05, y: rect.minY + height * 0.62),
            controlPoint2: CGPoint(x: rect.maxX - width * 0.23, y: rect.minY + height * 0.78)
        )
        path.close()
        return path
    }

    private static func star(in rect: CGRect) -> UIBezierPath {
        let path = UIBezierPath()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) * 0.5
        let innerRadius = outerRadius * 0.44
        for index in 0..<10 {
            let radius = index.isMultiple(of: 2) ? outerRadius : innerRadius
            let angle = CGFloat(index) * .pi / 5 - .pi / 2
            let point = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
            index == 0 ? path.move(to: point) : path.addLine(to: point)
        }
        path.close()
        return path
    }

    private static func cloud(in rect: CGRect) -> UIBezierPath {
        let path = UIBezierPath()
        let point: (CGFloat, CGFloat) -> CGPoint = { x, y in
            CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y)
        }

        path.move(to: point(0.18, 0.76))
        path.addCurve(to: point(0.08, 0.58), controlPoint1: point(0.10, 0.74), controlPoint2: point(0.06, 0.67))
        path.addCurve(to: point(0.24, 0.40), controlPoint1: point(0.08, 0.48), controlPoint2: point(0.14, 0.41))
        path.addCurve(to: point(0.43, 0.27), controlPoint1: point(0.28, 0.28), controlPoint2: point(0.35, 0.24))
        path.addCurve(to: point(0.68, 0.39), controlPoint1: point(0.55, 0.18), controlPoint2: point(0.66, 0.26))
        path.addCurve(to: point(0.91, 0.57), controlPoint1: point(0.82, 0.36), controlPoint2: point(0.91, 0.45))
        path.addCurve(to: point(0.80, 0.76), controlPoint1: point(0.93, 0.68), controlPoint2: point(0.88, 0.74))
        path.addLine(to: point(0.18, 0.76))
        path.close()
        return path
    }

    private static func flower(in rect: CGRect) -> UIBezierPath {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let points = (0..<12).map { index -> CGPoint in
            let angle = CGFloat(index) * .pi / 6 - .pi / 2
            let radius = (index.isMultiple(of: 2) ? 0.48 : 0.30) * min(rect.width, rect.height)
            return CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
        }

        let path = UIBezierPath()
        path.move(to: midpoint(points.last!, points[0]))
        for index in points.indices {
            path.addQuadCurve(
                to: midpoint(points[index], points[(index + 1) % points.count]),
                controlPoint: points[index]
            )
        }
        path.close()
        return path
    }

    private static func midpoint(_ first: CGPoint, _ second: CGPoint) -> CGPoint {
        CGPoint(x: (first.x + second.x) / 2, y: (first.y + second.y) / 2)
    }
}

private extension CGRect {
    func scaledAboutCenter(by scale: CGFloat) -> CGRect {
        let size = CGSize(width: width * scale, height: height * scale)
        return CGRect(
            x: midX - size.width / 2,
            y: midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }
}

private extension UIImage {
    func drawAspectFill(in rect: CGRect) {
        let scale = max(rect.width / size.width, rect.height / size.height)
        let drawSize = CGSize(width: size.width * scale, height: size.height * scale)
        let drawRect = CGRect(
            x: rect.midX - drawSize.width / 2,
            y: rect.midY - drawSize.height / 2,
            width: drawSize.width,
            height: drawSize.height
        )
        draw(in: drawRect)
    }

}
