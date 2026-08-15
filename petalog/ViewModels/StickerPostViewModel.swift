import Combine
import Foundation

@MainActor
final class StickerPostViewModel: ObservableObject {
    @Published var isUploading = false
    @Published var uploadProgress = 0.0
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
        uploadProgress = 0
        defer { isUploading = false }
        errorMessage = nil

        do {
            let posts = try await services.stickers.uploadSticker(
                stickerPNG: stickerPNG,
                draft: draft,
                groups: groups,
                user: user,
                onProgress: { [weak self] progress in
                    Task { @MainActor in
                        self?.uploadProgress = progress
                    }
                }
            )
            uploadProgress = 1
            return posts
        } catch {
            errorMessage = error.localizedDescription
            return []
        }
    }
}
