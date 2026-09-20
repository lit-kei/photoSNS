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

    func fetchUserCollectionStickers(userId: String, limit: Int = 240) async throws -> [StickerPost] {
        let snapshot = try await db.collection("stickers")
            .whereField("authorId", isEqualTo: userId)
            .getDocuments()

        let sortedStickers = snapshot.documents
            .map { StickerPost(id: $0.documentID, data: $0.data()) }
            .sorted { $0.createdAt > $1.createdAt }

        var seenAssetIds: Set<String> = []
        let uniqueStickers = sortedStickers.filter { sticker in
            let dedupeKey = sticker.assetId.isEmpty ? sticker.id : sticker.assetId
            guard !seenAssetIds.contains(dedupeKey) else { return false }
            seenAssetIds.insert(dedupeKey)
            return true
        }
        return Array(uniqueStickers.prefix(limit))
    }

    func uploadSticker(
        stickerPNG: Data,
        originalStickerPNG: Data? = nil,
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
        if let originalStickerPNG {
            guard !originalStickerPNG.isEmpty,
                  originalStickerPNG.count <= Self.maximumStickerBytes,
                  let originalImage = UIImage(data: originalStickerPNG),
                  let originalCGImage = originalImage.cgImage,
                  originalCGImage.width == 512,
                  originalCGImage.height == 512 else {
                throw PetankoError.message("色戻し用の画像を512pxで作成できませんでした。")
            }
        }

        let assetId = UUID().uuidString
        let storagePath = "stickerAssets/\(user.id)/\(assetId).png"
        let originalStoragePath = "stickerAssets/\(user.id)/\(assetId)-original.png"
        let stickerURL = try await upload(data: stickerPNG, path: storagePath, onStageChange: onStageChange)
        let originalStickerURL: URL?
        if let originalStickerPNG {
            do {
                originalStickerURL = try await upload(
                    data: originalStickerPNG,
                    path: originalStoragePath,
                    onStageChange: { _ in }
                )
            } catch {
                try? await storage.reference(withPath: storagePath).delete()
                throw error
            }
        } else {
            originalStickerURL = nil
        }
        onStageChange(.savingPost)
        let jobId = UUID().uuidString
        let jobRef = db.collection("stickerUploadJobs").document(jobId)
        let jobData: [String: Any] = [
            "userId": user.id,
            "assetId": assetId,
            "storagePath": storagePath,
            "downloadURL": stickerURL.absoluteString,
            "originalStoragePath": originalStickerURL == nil ? "" : originalStoragePath,
            "originalDownloadURL": originalStickerURL?.absoluteString ?? "",
            "draft": [
                "comment": draft.comment.trimmedForPetanko,
                "shape": draft.shape.rawValue,
                "decoration": draft.decoration.rawValue,
                "outlineColorHex": draft.outlineColorHex,
                "creationMode": draft.creationMode.rawValue,
                "effect": draft.effect.rawValue
            ],
            "groupIds": groups.map(\.id),
            "publishToBlog": publishToBlog,
            "authorName": user.displayName,
            "authorAvatar": user.avatar,
            "status": "pending",
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]
        do {
            try await jobRef.setData(jobData)
        } catch {
            try? await storage.reference(withPath: storagePath).delete()
            if originalStickerURL != nil {
                try? await storage.reference(withPath: originalStoragePath).delete()
            }
            throw error
        }

        let posts = try await waitForStickerUploadJob(jobId: jobId)

        // Remote persistence is complete at this point. Cache population can
        // continue without delaying the transition back to the home screen.
        Task {
            await RemoteImageCache.shared.store(data: stickerPNG, for: stickerURL)
            if let originalStickerPNG, let originalStickerURL {
                await RemoteImageCache.shared.store(data: originalStickerPNG, for: originalStickerURL)
            }
        }
        return posts
    }

    private func waitForStickerUploadJob(jobId: String) async throws -> [StickerPost] {
        let jobRef = db.collection("stickerUploadJobs").document(jobId)
        let deadline = Date().addingTimeInterval(120)
        while Date() < deadline {
            let snapshot = try await jobRef.getDocument(source: .server)
            let data = snapshot.data() ?? [:]
            let status = data["status"] as? String ?? "pending"
            if status == "completed" {
                let postData = data["posts"] as? [[String: Any]] ?? []
                return postData.compactMap { data in
                    guard let id = data["id"] as? String else { return nil }
                    var stickerData = data
                    stickerData.removeValue(forKey: "id")
                    return StickerPost(id: id, data: stickerData)
                }
            }
            if status == "failed" {
                let message = data["errorMessage"] as? String ?? "投稿処理に失敗しました。もう一度お試しください。"
                throw PetankoError.message(message)
            }
            try await Task.sleep(for: .seconds(1))
        }
        throw PetankoError.message("投稿処理をサーバーに送信しました。完了通知が届くまで少しお待ちください。")
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
            let originalStoragePath = "stickerAssets/\(sticker.authorId)/\(sticker.assetId)-original.png"
            try? await storage.reference(withPath: storagePath).delete()
            try? await storage.reference(withPath: originalStoragePath).delete()
            if let url = URL(string: sticker.stickerImageURL) {
                await RemoteImageCache.shared.remove(for: url)
            }
            if let url = URL(string: sticker.originalStickerImageURL),
               !sticker.originalStickerImageURL.isEmpty {
                await RemoteImageCache.shared.remove(for: url)
            }
        }
    }

    func reportSticker(_ sticker: StickerPost, user: AppUser, reason: String = "inappropriate_image") async throws {
        guard sticker.authorId != user.id else {
            throw PetankoError.message("自分の投稿は報告できません。")
        }

        let reportId = "\(sticker.id)_\(user.id)"
        let reportRef = db.collection("stickerReports").document(reportId)
        print("[StickerReport] writing stickerReports/\(reportId) stickerId=\(sticker.id) reporterId=\(user.id)")
        try await reportRef.setData([
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
        if let verification = try? await reportRef.getDocument(source: .server) {
            print("[StickerReport] wrote stickerReports/\(reportId) serverExists=\(verification.exists)")
        } else {
            print("[StickerReport] wrote stickerReports/\(reportId) but server verification was skipped")
        }
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
