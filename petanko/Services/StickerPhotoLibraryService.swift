import Foundation
import Photos
import UIKit

enum StickerPhotoLibraryService {
    static func saveStickerPNG(_ data: Data) async throws {
        guard !data.isEmpty,
              UIImage(data: data) != nil else {
            throw PetankoError.message("保存できるステッカー画像がありません。")
        }

        try await ensureAddOnlyAuthorization()
        try await performSave(data: data)
    }

    static func saveSticker(from urlString: String) async throws {
        guard let url = URL(string: urlString), !urlString.isEmpty else {
            throw PetankoError.message("ステッカー画像のURLを確認できません。")
        }

        let cachedImage = try await RemoteImageCache.shared.image(for: url)
        guard let pngData = cachedImage.image.pngData() else {
            throw PetankoError.message("ステッカー画像をPNGとして保存できませんでした。")
        }
        try await saveStickerPNG(pngData)
    }

    private static func ensureAddOnlyAuthorization() async throws {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        switch status {
        case .authorized, .limited:
            return
        case .notDetermined:
            let requestedStatus = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            guard requestedStatus == .authorized || requestedStatus == .limited else {
                throw PetankoError.message("写真への追加が許可されていません。設定アプリから写真への追加を許可してください。")
            }
        case .denied, .restricted:
            throw PetankoError.message("写真への追加が許可されていません。設定アプリから写真への追加を許可してください。")
        @unknown default:
            throw PetankoError.message("写真への追加権限を確認できませんでした。")
        }
    }

    private static func performSave(data: Data) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            let options = PHAssetResourceCreationOptions()
            options.uniformTypeIdentifier = "public.png"
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .photo, data: data, options: options)
        }
    }
}
