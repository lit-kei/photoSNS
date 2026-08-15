import FirebaseFirestore
import FirebaseStorage
import Foundation
import UIKit

final class StickerService {
    private let db: Firestore
    private let storage: Storage

    init(db: Firestore, storage: Storage) {
        self.db = db
        self.storage = storage
    }

    func observeStickers(groupId: String, dateKey: String, onChange: @escaping ([StickerPost], Error?) -> Void) -> ListenerRegistration {
        db.collection("stickers")
            .whereField("groupId", isEqualTo: groupId)
            .whereField("dateKey", isEqualTo: dateKey)
            .addSnapshotListener { snapshot, error in
                if let error {
                    onChange([], error)
                    return
                }

                let stickers = snapshot?.documents
                    .map { StickerPost(id: $0.documentID, data: $0.data()) }
                    .sorted { $0.createdAt < $1.createdAt } ?? []
                onChange(stickers, nil)
            }
    }

    func uploadSticker(originalImage: UIImage, stickerPNG: Data, draft: StickerDraft, group: PetalogGroup, user: AppUser) async throws -> StickerPost {
        guard let originalData = originalImage.jpegData(compressionQuality: 0.86) else {
            throw PetalogError.message("元写真の保存データを作れませんでした。")
        }

        let stickerId = UUID().uuidString
        let dateKey = Date().petalogDateKey
        let diaryId = "\(group.id)_\(dateKey)"
        let originalPath = "originalPhotos/\(user.id)/\(stickerId).jpg"
        let stickerPath = "stickers/\(group.id)/\(diaryId)/\(stickerId).png"

        let originalURL = try await upload(data: originalData, path: originalPath, contentType: "image/jpeg")
        let stickerURL = try await upload(data: stickerPNG, path: stickerPath, contentType: "image/png")

        let layout = StickerLayout(
            stickerId: stickerId,
            x: Double.random(in: -80...80),
            y: Double.random(in: -140...140),
            scale: Double.random(in: 0.86...1.12),
            rotation: Double.random(in: -13...13),
            zIndex: Int(Date().timeIntervalSince1970)
        )

        let post = StickerPost(
            id: stickerId,
            groupId: group.id,
            diaryId: diaryId,
            dateKey: dateKey,
            authorId: user.id,
            authorName: user.displayName,
            authorAvatar: user.avatar,
            comment: draft.comment.trimmedForPetalog,
            shape: draft.shape,
            decoration: draft.decoration,
            originalPhotoURL: originalURL.absoluteString,
            stickerImageURL: stickerURL.absoluteString,
            layout: layout
        )

        let diary = DiaryPage(id: diaryId, groupId: group.id, dateKey: dateKey, title: Date().petalogShortTitle)
        let batch = db.batch()
        batch.setData(diary.dictionary, forDocument: db.collection("diaries").document(diaryId), merge: true)
        batch.setData(post.dictionary, forDocument: db.collection("stickers").document(stickerId))
        batch.updateData(["diaryCount": FieldValue.increment(Int64(1))], forDocument: db.collection("groups").document(group.id))
        try await batch.commit()
        return post
    }

    func deleteSticker(_ sticker: StickerPost, user: AppUser) async throws {
        guard sticker.authorId == user.id else {
            throw PetalogError.message("自分が撮った写真だけ削除できます。")
        }

        let diaryRef = db.collection("diaries").document(sticker.diaryId)
        let diarySnapshot = try await diaryRef.getDocument()
        var diaryData = diarySnapshot.data() ?? [:]
        let layouts = diaryData["stickerLayout"] as? [[String: Any]] ?? []
        diaryData["stickerLayout"] = layouts.filter { $0["stickerId"] as? String != sticker.id }
        diaryData["updatedAt"] = FieldValue.serverTimestamp()

        let batch = db.batch()
        batch.deleteDocument(db.collection("stickers").document(sticker.id))
        batch.setData(diaryData, forDocument: diaryRef, merge: true)
        batch.updateData(["diaryCount": FieldValue.increment(Int64(-1))], forDocument: db.collection("groups").document(sticker.groupId))
        try await batch.commit()

        try? await storage.reference(forURL: sticker.stickerImageURL).delete()
        try? await storage.reference(forURL: sticker.originalPhotoURL).delete()
    }

    private func upload(data: Data, path: String, contentType: String) async throws -> URL {
        let ref = storage.reference(withPath: path)
        let metadata = StorageMetadata()
        metadata.contentType = contentType

        _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<StorageMetadata, Error>) in
            ref.putData(data, metadata: metadata) { metadata, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let metadata {
                    continuation.resume(returning: metadata)
                } else {
                    continuation.resume(throwing: PetalogError.message("画像アップロードに失敗しました。"))
                }
            }
        }

        return try await ref.downloadURL()
    }
}
