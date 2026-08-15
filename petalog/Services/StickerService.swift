import FirebaseFirestore
import FirebaseStorage
import Foundation
import UIKit

final class StickerService {
    private static let maximumStickerBytes = 2 * 1024 * 1024

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

    func uploadSticker(stickerPNG: Data, draft: StickerDraft, groups: [PetalogGroup], user: AppUser) async throws -> [StickerPost] {
        guard !groups.isEmpty else { return [] }
        guard !stickerPNG.isEmpty, stickerPNG.count <= Self.maximumStickerBytes else {
            throw PetalogError.message("ステッカー画像が大きすぎます。もう一度作成してください。")
        }
        guard let image = UIImage(data: stickerPNG),
              let cgImage = image.cgImage,
              cgImage.width == 512,
              cgImage.height == 512 else {
            throw PetalogError.message("ステッカー画像を512pxで作成できませんでした。")
        }

        let assetId = UUID().uuidString
        let dateKey = Date().petalogDateKey
        let storagePath = "stickerAssets/\(user.id)/\(assetId).png"
        let stickerURL = try await upload(data: stickerPNG, path: storagePath)
        let createdAt = Date()
        let posts = groups.enumerated().map { index, group in
            let postId = UUID().uuidString
            let diaryId = "\(group.id)_\(dateKey)"
            let layout = StickerLayout(
                stickerId: postId,
                x: Double.random(in: -80...80),
                y: Double.random(in: -140...140),
                scale: Double.random(in: 0.86...1.12),
                rotation: Double.random(in: -13...13),
                zIndex: Int(createdAt.timeIntervalSince1970) + index
            )
            return StickerPost(
                id: postId,
                assetId: assetId,
                groupId: group.id,
                diaryId: diaryId,
                dateKey: dateKey,
                authorId: user.id,
                authorName: user.displayName,
                authorAvatar: user.avatar,
                comment: draft.comment.trimmedForPetalog,
                shape: draft.shape,
                decoration: draft.decoration,
                stickerImageURL: stickerURL.absoluteString,
                layout: layout,
                createdAt: createdAt
            )
        }

        let batch = db.batch()
        batch.setData(
            [
                "ownerId": user.id,
                "storagePath": storagePath,
                "downloadURL": stickerURL.absoluteString,
                "referenceCount": posts.count,
                "createdAt": Timestamp(date: createdAt)
            ],
            forDocument: db.collection("stickerAssets").document(assetId)
        )
        for (group, post) in zip(groups, posts) {
            let diary = DiaryPage(id: post.diaryId, groupId: group.id, dateKey: dateKey, title: createdAt.petalogShortTitle)
            batch.setData(diary.dictionary, forDocument: db.collection("diaries").document(post.diaryId), merge: true)
            batch.setData(post.dictionary, forDocument: db.collection("stickers").document(post.id))
            batch.updateData(["diaryCount": FieldValue.increment(Int64(1))], forDocument: db.collection("groups").document(group.id))
        }

        do {
            try await batch.commit()
        } catch {
            try? await storage.reference(withPath: storagePath).delete()
            throw error
        }

        await StickerImageCache.shared.store(data: stickerPNG, for: stickerURL)
        return posts
    }

    func deleteSticker(_ sticker: StickerPost, user: AppUser) async throws {
        guard sticker.authorId == user.id else {
            throw PetalogError.message("自分が撮った写真だけ削除できます。")
        }

        let stickerRef = db.collection("stickers").document(sticker.id)
        let diaryRef = db.collection("diaries").document(sticker.diaryId)
        let assetRef = db.collection("stickerAssets").document(sticker.assetId)
        let groupRef = db.collection("groups").document(sticker.groupId)

        let result = try await db.runTransaction { transaction, errorPointer -> Any? in
            do {
                let assetSnapshot = try transaction.getDocument(assetRef)
                let diarySnapshot = try transaction.getDocument(diaryRef)
                let referenceCount = (assetSnapshot.data()?["referenceCount"] as? NSNumber)?.intValue ?? 1
                var diaryData = diarySnapshot.data() ?? [:]
                let layouts = diaryData["stickerLayout"] as? [[String: Any]] ?? []
                diaryData["stickerLayout"] = layouts.filter { $0["stickerId"] as? String != sticker.id }
                diaryData["updatedAt"] = FieldValue.serverTimestamp()

                transaction.deleteDocument(stickerRef)
                transaction.setData(diaryData, forDocument: diaryRef, merge: true)
                transaction.updateData(["diaryCount": FieldValue.increment(Int64(-1))], forDocument: groupRef)

                if assetSnapshot.exists {
                    if referenceCount <= 1 {
                        transaction.deleteDocument(assetRef)
                    } else {
                        transaction.updateData(["referenceCount": referenceCount - 1], forDocument: assetRef)
                    }
                }
                return referenceCount <= 1
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        }

        if result as? Bool == true {
            let storagePath = "stickerAssets/\(sticker.authorId)/\(sticker.assetId).png"
            try? await storage.reference(withPath: storagePath).delete()
            if let url = URL(string: sticker.stickerImageURL) {
                await StickerImageCache.shared.remove(for: url)
            }
        }
    }

    private func upload(data: Data, path: String) async throws -> URL {
        let ref = storage.reference(withPath: path)
        let metadata = StorageMetadata()
        metadata.contentType = "image/png"
        metadata.cacheControl = "private,max-age=31536000,immutable"

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
