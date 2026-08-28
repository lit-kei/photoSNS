import CoreImage
import UIKit
import Vision

enum ForegroundExtractionError: LocalizedError {
    case invalidImage
    case noForeground
    case renderingFailed

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            "写真を読み込めませんでした。別の写真でお試しください。"
        case .noForeground:
            "切り抜ける人物や物を見つけられませんでした。"
        case .renderingFailed:
            "背景透過画像を作成できませんでした。"
        }
    }
}

enum ForegroundExtractionService {
    static func extract(from originalImage: UIImage) async throws -> UIImage {
        try Task.checkCancellation()

        let source = originalImage.petankoResized(maxDimension: 1_600)
        guard let cgImage = source.cgImage else {
            throw ForegroundExtractionError.invalidImage
        }

        let handler = ImageRequestHandler(cgImage)
        let observation = try await handler.perform(GenerateForegroundInstanceMaskRequest())
        try Task.checkCancellation()

        guard let observation, !observation.allInstances.isEmpty else {
            throw ForegroundExtractionError.noForeground
        }

        let pixelBuffer = try observation.generateMaskedImage(
            for: observation.allInstances,
            imageFrom: handler,
            croppedToInstancesExtent: true
        )
        try Task.checkCancellation()

        let image = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext(options: [.cacheIntermediates: false])
        guard let output = context.createCGImage(image, from: image.extent) else {
            throw ForegroundExtractionError.renderingFailed
        }
        return UIImage(cgImage: output, scale: 1, orientation: .up)
    }
}
