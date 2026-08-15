import Combine
import Foundation

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

    func upload(stickerPNG: Data, draft: StickerDraft, groups: [PetalogGroup], user: AppUser) async -> [StickerPost] {
        guard !groups.isEmpty else { return [] }
        isUploading = true
        defer { isUploading = false }
        errorMessage = nil

        do {
            return try await services.stickers.uploadSticker(
                stickerPNG: stickerPNG,
                draft: draft,
                groups: groups,
                user: user
            )
        } catch {
            errorMessage = error.localizedDescription
            return []
        }
    }
}
