import Combine
import Foundation
import UIKit

@MainActor
final class StickerPostViewModel: ObservableObject {
    @Published var isUploading = false
    @Published var errorMessage: String?

    private let services: AppServices

    init() {
        self.services = AppServices.shared
    }

    init(services: AppServices) {
        self.services = services
    }

    func upload(originalImage: UIImage, stickerPNG: Data, draft: StickerDraft, group: PetalogGroup, user: AppUser) async -> StickerPost? {
        isUploading = true
        defer { isUploading = false }

        do {
            return try await services.stickers.uploadSticker(originalImage: originalImage, stickerPNG: stickerPNG, draft: draft, group: group, user: user)
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}
