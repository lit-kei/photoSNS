import FirebaseFirestore
import FirebaseStorage
import Foundation

final class DiaryService {
    static let editLockLeaseDuration: TimeInterval = 90

    private let db: Firestore
    private let storage: Storage

    init(db: Firestore, storage: Storage) {
        self.db = db
        self.storage = storage
    }

    func diaryId(groupId: String, dateKey: String) -> String {
        "\(groupId)_\(dateKey)"
    }

    func ensureTodayDiary(group: PetankoGroup, dateKey: String) async throws -> DiaryPage {
        let id = diaryId(groupId: group.id, dateKey: dateKey)
        let ref = db.collection("diaries").document(id)
        let snapshot = try await ref.getDocument()
        if let data = snapshot.data(), snapshot.exists {
            return DiaryPage(id: id, data: data)
        }

        let page = DiaryPage(id: id, groupId: group.id, dateKey: dateKey, title: Date().petankoShortTitle)
        try await ref.setData(page.dictionary, merge: true)
        return page
    }

    func observeDiary(groupId: String, dateKey: String, onChange: @escaping (DiaryPage?, Error?) -> Void) -> ListenerRegistration {
        let id = diaryId(groupId: groupId, dateKey: dateKey)
        return db.collection("diaries").document(id).addSnapshotListener { snapshot, error in
            if let error {
                onChange(nil, error)
                return
            }
            guard let snapshot, let data = snapshot.data(), snapshot.exists else {
                onChange(nil, nil)
                return
            }
            onChange(DiaryPage(id: id, data: data), nil)
        }
    }

    func saveDiaryLayout(_ diary: DiaryPage) async throws {
        try await db.collection("diaries").document(diary.id).setData(diary.dictionary, merge: true)
    }

    func saveDiaryLayout(
        _ diary: DiaryPage,
        backgroundImageData: Data?,
        previousBackgroundImageURL: String?,
        photoStampImageData: [String: Data] = [:],
        previousPhotoStampImageURLs: [String] = []
    ) async throws -> DiaryPage {
        var page = diary
        var uploadedBackgroundURL: URL?
        var uploadedPhotoStampURLs: [URL] = []

        if let backgroundImageData {
            let url = try await uploadBackgroundImage(
                groupId: diary.groupId,
                diaryId: diary.id,
                imageData: backgroundImageData
            )
            uploadedBackgroundURL = url
            page.backgroundImageURL = url.absoluteString
        }

        for (stampID, imageData) in photoStampImageData {
            guard let stampIndex = page.stampItems.firstIndex(where: { $0.id == stampID }) else { continue }
            let url = try await uploadPhotoStampImage(
                groupId: diary.groupId,
                diaryId: diary.id,
                stampId: stampID,
                imageData: imageData
            )
            uploadedPhotoStampURLs.append(url)
            page.stampItems[stampIndex].imageURL = url.absoluteString
        }

        do {
            try await saveDiaryLayout(page)
        } catch {
            if let uploadedBackgroundURL {
                await deleteBackgroundImage(at: uploadedBackgroundURL.absoluteString)
            }
            for url in uploadedPhotoStampURLs {
                await deleteBackgroundImage(at: url.absoluteString)
            }
            throw error
        }

        if let previousBackgroundImageURL,
           !previousBackgroundImageURL.isEmpty,
           previousBackgroundImageURL != page.backgroundImageURL {
            await deleteBackgroundImage(at: previousBackgroundImageURL)
        }

        let currentPhotoStampURLs = Set(page.stampItems.compactMap(\.imageURL))
        for oldURL in Set(previousPhotoStampImageURLs) where !currentPhotoStampURLs.contains(oldURL) {
            await deleteBackgroundImage(at: oldURL)
        }

        return page
    }

    func acquireEditLock(groupId: String, diaryId: String, user: AppUser) async throws -> Bool {
        let ref = db.collection("editLocks").document(diaryId)
        let now = Date()
        let result = try await db.runTransaction { transaction, errorPointer -> Any? in
            do {
                let snapshot = try transaction.getDocument(ref)
                if let data = snapshot.data(),
                   let lockedBy = data["lockedBy"] as? String,
                   lockedBy != user.id,
                   let expiresAt = data["expiresAt"] as? Timestamp,
                   expiresAt.dateValue() > now {
                    return false
                }

                transaction.setData(
                    self.editLockData(groupId: groupId, diaryId: diaryId, user: user, now: now),
                    forDocument: ref,
                    merge: true
                )
                return true
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        }
        return result as? Bool == true
    }

    func renewEditLock(groupId: String, diaryId: String, user: AppUser) async throws -> Bool {
        let ref = db.collection("editLocks").document(diaryId)
        let now = Date()
        let result = try await db.runTransaction { transaction, errorPointer -> Any? in
            do {
                let snapshot = try transaction.getDocument(ref)
                if let data = snapshot.data(),
                   let lockedBy = data["lockedBy"] as? String,
                   lockedBy != user.id {
                    return false
                }

                transaction.setData(
                    self.editLockData(groupId: groupId, diaryId: diaryId, user: user, now: now),
                    forDocument: ref,
                    merge: true
                )
                return true
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        }
        return result as? Bool == true
    }

    func releaseEditLock(diaryId: String, userId: String) async throws {
        let ref = db.collection("editLocks").document(diaryId)
        let snapshot = try await ref.getDocument()
        guard snapshot.data()?["lockedBy"] as? String == userId else { return }
        try await ref.delete()
    }

    private func editLockData(groupId: String, diaryId: String, user: AppUser, now: Date) -> [String: Any] {
        [
            "groupId": groupId,
            "diaryId": diaryId,
            "lockedBy": user.id,
            "lockedByName": user.displayName,
            "expiresAt": Timestamp(date: now.addingTimeInterval(Self.editLockLeaseDuration)),
            "updatedAt": FieldValue.serverTimestamp()
        ]
    }

    private func uploadBackgroundImage(groupId: String, diaryId: String, imageData: Data) async throws -> URL {
        let uploadData = imageData.petankoOptimizedJPEG(
            maxDimension: 1_800,
            quality: 0.82,
            maximumBytes: 1_500_000
        )
        let ref = storage.reference(
            withPath: "groupIcons/\(groupId)/diary-background-\(diaryId)-\(UUID().uuidString).jpg"
        )
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        metadata.cacheControl = "private,max-age=31536000,immutable"

        _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<StorageMetadata, Error>) in
            ref.putData(uploadData, metadata: metadata) { metadata, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let metadata {
                    continuation.resume(returning: metadata)
                } else {
                    continuation.resume(throwing: PetankoError.message("背景写真の保存に失敗しました。"))
                }
            }
        }

        do {
            let url = try await ref.downloadURL()
            Task { await RemoteImageCache.shared.store(data: uploadData, for: url) }
            return url
        } catch {
            try? await ref.delete()
            throw error
        }
    }

    private func uploadPhotoStampImage(
        groupId: String,
        diaryId: String,
        stampId: String,
        imageData: Data
    ) async throws -> URL {
        let uploadData = imageData.petankoOptimizedJPEG(
            maxDimension: 1_200,
            quality: 0.84,
            maximumBytes: 1_000_000
        )
        let ref = storage.reference(
            withPath: "groupIcons/\(groupId)/diary-stamp-\(diaryId)-\(stampId)-\(UUID().uuidString).jpg"
        )
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        metadata.cacheControl = "private,max-age=31536000,immutable"

        _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<StorageMetadata, Error>) in
            ref.putData(uploadData, metadata: metadata) { metadata, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let metadata {
                    continuation.resume(returning: metadata)
                } else {
                    continuation.resume(throwing: PetankoError.message("写真スタンプの保存に失敗しました。"))
                }
            }
        }

        do {
            let url = try await ref.downloadURL()
            Task { await RemoteImageCache.shared.store(data: uploadData, for: url) }
            return url
        } catch {
            try? await ref.delete()
            throw error
        }
    }

    private func deleteBackgroundImage(at urlString: String) async {
        guard let url = URL(string: urlString) else { return }
        try? await storage.reference(forURL: urlString).delete()
        await RemoteImageCache.shared.remove(for: url)
    }
}
