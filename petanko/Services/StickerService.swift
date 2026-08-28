import FirebaseFirestore
import FirebaseStorage
import Foundation
import UIKit

enum StickerUploadStage: Sendable {
    case uploading(Double)
    case resolvingDownloadURL
    case savingPost
}

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

    func observeUnreadStickerCount(
        groupId: String,
        userId: String,
        createdAfter lastReadAt: Date,
        onChange: @escaping (Int, Error?) -> Void
    ) -> ListenerRegistration {
        db.collection("stickers")
            .whereField("groupId", isEqualTo: groupId)
            .addSnapshotListener { snapshot, error in
                if let error {
                    onChange(0, error)
                    return
                }

                let unreadCount = snapshot?.documents.reduce(into: 0) { count, document in
                    let data = document.data()
                    guard data["authorId"] as? String != userId else { return }
                    guard let createdAt = (data["createdAt"] as? Timestamp)?.dateValue(),
                          createdAt > lastReadAt else { return }
                    count += 1
                } ?? 0
                onChange(unreadCount, nil)
            }
    }

    func observeTodayBlogStickers(authorIds: [String], onChange: @escaping ([StickerPost], Error?) -> Void) -> [ListenerRegistration] {
        let uniqueAuthorIds = Array(Set(authorIds).filter { !$0.isEmpty }).sorted()
        guard !uniqueAuthorIds.isEmpty else {
            onChange([], nil)
            return []
        }

        let todayKey = Date().petankoDateKey
        let chunks = uniqueAuthorIds.chunked(into: 10)
        let lock = NSLock()
        var postsByChunk: [Int: [String: StickerPost]] = [:]

        return chunks.enumerated().map { index, ids in
            db.collection("stickers")
                .whereField("target", isEqualTo: StickerPostTarget.blog.rawValue)
                .whereField("dateKey", isEqualTo: todayKey)
                .whereField("authorId", in: ids)
                .addSnapshotListener { snapshot, error in
                    if let error {
                        onChange([], error)
                        return
                    }

                    let posts = snapshot?.documents
                        .map { StickerPost(id: $0.documentID, data: $0.data()) } ?? []

                    lock.lock()
                    postsByChunk[index] = Dictionary(uniqueKeysWithValues: posts.map { ($0.id, $0) })
                    let mergedPosts = postsByChunk.values
                        .flatMap { $0.values }
                        .sorted { $0.createdAt > $1.createdAt }
                    lock.unlock()

                    onChange(mergedPosts, nil)
                }
        }
    }

    func uploadSticker(
        stickerPNG: Data,
        draft: StickerDraft,
        groups: [PetankoGroup],
        publishToBlog: Bool,
        user: AppUser,
        onStageChange: @escaping (StickerUploadStage) -> Void = { _ in }
    ) async throws -> [StickerPost] {
        guard publishToBlog || !groups.isEmpty else { return [] }
        guard !stickerPNG.isEmpty, stickerPNG.count <= Self.maximumStickerBytes else {
            throw PetankoError.message("ステッカー画像が大きすぎます。もう一度作成してください。")
        }
        guard let image = UIImage(data: stickerPNG),
              let cgImage = image.cgImage,
              cgImage.width == 512,
              cgImage.height == 512 else {
            throw PetankoError.message("ステッカー画像を512pxで作成できませんでした。")
        }

        let assetId = UUID().uuidString
        let dateKey = Date().petankoDateKey
        let storagePath = "stickerAssets/\(user.id)/\(assetId).png"
        let stickerURL = try await upload(data: stickerPNG, path: storagePath, onStageChange: onStageChange)
        onStageChange(.savingPost)
        let createdAt = Date()
        var posts: [StickerPost] = []

        if publishToBlog {
            let postId = UUID().uuidString
            let layout = StickerLayout(
                stickerId: postId,
                x: Double.random(in: -80...80),
                y: Double.random(in: -140...140),
                scale: Double.random(in: 0.86...1.12),
                rotation: Double.random(in: -13...13),
                zIndex: Int(createdAt.timeIntervalSince1970)
            )
            posts.append(
                StickerPost(
                    id: postId,
                    target: .blog,
                    assetId: assetId,
                    groupId: "",
                    diaryId: "",
                    dateKey: dateKey,
                    authorId: user.id,
                    authorName: user.displayName,
                    authorAvatar: user.avatar,
                    comment: draft.comment.trimmedForPetanko,
                    shape: draft.shape,
                    decoration: draft.decoration,
                    outlineColorHex: draft.outlineColorHex,
                    creationMode: draft.creationMode,
                    effect: draft.effect,
                    stickerImageURL: stickerURL.absoluteString,
                    layout: layout,
                    createdAt: createdAt
                )
            )
        }

        let groupPosts = groups.enumerated().map { index, group in
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
                target: .group,
                assetId: assetId,
                groupId: group.id,
                diaryId: diaryId,
                dateKey: dateKey,
                authorId: user.id,
                authorName: user.displayName,
                authorAvatar: user.avatar,
                comment: draft.comment.trimmedForPetanko,
                shape: draft.shape,
                decoration: draft.decoration,
                outlineColorHex: draft.outlineColorHex,
                creationMode: draft.creationMode,
                effect: draft.effect,
                stickerImageURL: stickerURL.absoluteString,
                layout: layout,
                createdAt: createdAt
            )
        }
        posts.append(contentsOf: groupPosts)

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
        if publishToBlog, let blogPost = posts.first(where: { $0.target == .blog }) {
            batch.setData(blogPost.dictionary, forDocument: db.collection("stickers").document(blogPost.id))
        }
        for (group, post) in zip(groups, groupPosts) {
            batch.setData(
                [
                    "groupId": group.id,
                    "dateKey": dateKey,
                    "stickerLayout": FieldValue.arrayUnion([post.layout.dictionary]),
                    "updatedAt": FieldValue.serverTimestamp()
                ],
                forDocument: db.collection("diaries").document(post.diaryId),
                merge: true
            )
            batch.setData(post.dictionary, forDocument: db.collection("stickers").document(post.id))
            batch.updateData(["diaryCount": FieldValue.increment(Int64(1))], forDocument: db.collection("groups").document(group.id))
        }

        do {
            try await batch.commit()
        } catch {
            try? await storage.reference(withPath: storagePath).delete()
            throw error
        }

        // Remote persistence is complete at this point. Cache population can
        // continue without delaying the transition back to the home screen.
        Task {
            await RemoteImageCache.shared.store(data: stickerPNG, for: stickerURL)
        }
        return posts
    }

    func deleteSticker(_ sticker: StickerPost, user: AppUser) async throws {
        guard sticker.authorId == user.id else {
            throw PetankoError.message("自分が撮った写真だけ削除できます。")
        }

        let stickerRef = db.collection("stickers").document(sticker.id)
        let assetRef = db.collection("stickerAssets").document(sticker.assetId)

        let result = try await db.runTransaction { transaction, errorPointer -> Any? in
            do {
                let assetSnapshot = try transaction.getDocument(assetRef)
                let referenceCount = (assetSnapshot.data()?["referenceCount"] as? NSNumber)?.intValue ?? 1

                transaction.deleteDocument(stickerRef)
                if sticker.target == .group {
                    let diaryRef = self.db.collection("diaries").document(sticker.diaryId)
                    let groupRef = self.db.collection("groups").document(sticker.groupId)
                    let diarySnapshot = try transaction.getDocument(diaryRef)
                    var diaryData = diarySnapshot.data() ?? [:]
                    let layouts = diaryData["stickerLayout"] as? [[String: Any]] ?? []
                    diaryData["stickerLayout"] = layouts.filter { $0["stickerId"] as? String != sticker.id }
                    diaryData["updatedAt"] = FieldValue.serverTimestamp()
                    transaction.setData(diaryData, forDocument: diaryRef, merge: true)
                    transaction.updateData(["diaryCount": FieldValue.increment(Int64(-1))], forDocument: groupRef)
                }

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
                await RemoteImageCache.shared.remove(for: url)
            }
        }
    }

    func reportSticker(_ sticker: StickerPost, user: AppUser, reason: String = "inappropriate_image") async throws {
        guard sticker.authorId != user.id else {
            throw PetankoError.message("自分の投稿は報告できません。")
        }

        let reportId = "\(sticker.id)_\(user.id)"
        try await db.collection("stickerReports").document(reportId).setData([
            "stickerId": sticker.id,
            "assetId": sticker.assetId,
            "stickerImageURL": sticker.stickerImageURL,
            "reportedAuthorId": sticker.authorId,
            "reportedAuthorName": sticker.authorName,
            "reporterId": user.id,
            "reporterName": user.displayName,
            "reason": reason,
            "createdAt": FieldValue.serverTimestamp(),
            "status": "open"
        ], merge: false)
    }

    private func upload(
        data: Data,
        path: String,
        onStageChange: @escaping (StickerUploadStage) -> Void
    ) async throws -> URL {
        let ref = storage.reference(withPath: path)
        let metadata = StorageMetadata()
        metadata.contentType = "image/png"
        metadata.cacheControl = "private,max-age=31536000,immutable"

        _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<StorageMetadata, Error>) in
            let uploadTask = ref.putData(data, metadata: metadata) { metadata, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let metadata {
                    continuation.resume(returning: metadata)
                } else {
                    continuation.resume(throwing: PetankoError.message("画像アップロードに失敗しました。"))
                }
            }
            _ = uploadTask.observe(.progress) { snapshot in
                onStageChange(.uploading(snapshot.progress?.fractionCompleted ?? 0))
            }
        }

        onStageChange(.resolvingDownloadURL)
        do {
            return try await ref.downloadURL()
        } catch {
            try? await ref.delete()
            throw error
        }
    }
}
