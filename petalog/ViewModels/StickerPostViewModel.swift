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

    func upload(originalImage: UIImage, stickerPNG: Data, draft: StickerDraft, groups: [PetalogGroup], user: AppUser) async -> [StickerPost] {
        guard !groups.isEmpty else { return [] }
        isUploading = true
        defer { isUploading = false }
        errorMessage = nil

        var posts: [StickerPost] = []
        var failedGroupNames: [String] = []

        for group in groups {
            do {
                let post = try await services.stickers.uploadSticker(
                    originalImage: originalImage,
                    stickerPNG: stickerPNG,
                    draft: draft,
                    group: group,
                    user: user
                )
                posts.append(post)
            } catch {
                failedGroupNames.append(group.name)
            }
        }

        if !failedGroupNames.isEmpty {
            errorMessage = "投稿できなかったグループ: \(failedGroupNames.joined(separator: "、"))"
        }

        return posts
    }
}
