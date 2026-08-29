import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import Foundation

enum AccountDeletionPostRetentionPolicy: String, CaseIterable, Hashable {
    case deletePosts
    case anonymizePosts

    var title: String {
        switch self {
        case .deletePosts:
            return "投稿も削除"
        case .anonymizePosts:
            return "匿名化して投稿を残す"
        }
    }
}

enum AccountDeletionStep: Hashable {
    case reauthenticating
    case deletingPosts
    case deletingSocialData
    case leavingGroups
    case deletingBlocks
    case deletingProfileStorage
    case deletingUserDocument
    case deletingAuthUser
    case completed

    var title: String {
        switch self {
        case .reauthenticating:
            return "ログイン確認中"
        case .deletingPosts:
            return "投稿データを整理中"
        case .deletingSocialData:
            return "友達・通知データを削除中"
        case .leavingGroups:
            return "グループから脱退中"
        case .deletingBlocks:
            return "ブロック情報を削除中"
        case .deletingProfileStorage:
            return "プロフィール画像を削除中"
        case .deletingUserDocument:
            return "プロフィールデータを削除中"
        case .deletingAuthUser:
            return "ログインアカウントを削除中"
        case .completed:
            return "削除が完了しました"
        }
    }

    var message: String {
        switch self {
        case .reauthenticating:
            return "安全のため、もう一度ログイン状態を確認しています。"
        case .deletingPosts:
            return "選択した方針に沿って投稿を処理しています。"
        case .deletingSocialData:
            return "友達、申請、通知、編集ロックを整理しています。"
        case .leavingGroups:
            return "参加中のグループからアカウントを外しています。"
        case .deletingBlocks:
            return "ブロックした/された情報を削除しています。"
        case .deletingProfileStorage:
            return "プロフィール画像などの保存データを確認しています。"
        case .deletingUserDocument:
            return "users コレクションのプロフィールを削除しています。"
        case .deletingAuthUser:
            return "Firebase Auth のログインアカウントを削除しています。"
        case .completed:
            return "サインアウト状態へ切り替えています。"
        }
    }
}

final class AccountDeletionService {
    static let deletedUserAuthorId = "deleted-user"
    static let deletedUserDisplayName = "退会済みユーザー"
    static let deletedUserAvatar = "system:person.fill"

    private let db: Firestore
    private let storage: Storage
    private let auth: AuthService

    init(db: Firestore, storage: Storage, auth: AuthService) {
        self.db = db
        self.storage = storage
        self.auth = auth
    }

    func deleteAccount(
        user: AppUser,
        password: String?,
        postRetentionPolicy: AccountDeletionPostRetentionPolicy,
        onProgress: @escaping @MainActor (AccountDeletionStep) -> Void = { _ in }
    ) async throws {
        try await runStep(
            .reauthenticating,
            failureMessage: "ログイン確認に失敗しました。もう一度パスワードを入力してください。",
            preservesAuthErrors: true,
            onProgress: onProgress
        ) {
            if let password, !password.isEmpty {
                try await auth.reauthenticate(password: password)
            }
        }

        try await runStep(
            .deletingPosts,
            failureMessage: "投稿データの処理に失敗しました。Firestore Rules の stickers / stickerAssets を確認してください。",
            onProgress: onProgress
        ) {
            switch postRetentionPolicy {
            case .deletePosts:
                try await deleteOwnedStickers(userId: user.id)
            case .anonymizePosts:
                try await anonymizeOwnedStickers(userId: user.id)
            }
        }

        try await runStep(
            .deletingSocialData,
            failureMessage: "友達・通知データの削除に失敗しました。Firestore Rules の friendships / friendRequests / notifications / editLocks を確認してください。",
            onProgress: onProgress
        ) {
            try await deleteSocialData(userId: user.id)
        }

        try await runStep(
            .leavingGroups,
            failureMessage: "グループからの脱退処理に失敗しました。Firestore Rules の groups / groupMembers を確認してください。",
            onProgress: onProgress
        ) {
            try await removeFromGroups(userId: user.id)
        }

        try await runStep(
            .deletingBlocks,
            failureMessage: "ブロック情報の削除に失敗しました。Firestore Rules の users/{uid}/blockedUsers を確認してください。",
            onProgress: onProgress
        ) {
            try await deleteInboundBlockReferences(userId: user.id)
            try await deleteAccountCollections(userId: user.id)
        }

        try await runStep(
            .deletingProfileStorage,
            failureMessage: "プロフィール画像の削除に失敗しました。Storage Rules の profilePhotos を確認してください。",
            onProgress: onProgress
        ) {
            try await deleteProfileStorage(user: user)
        }

        try await runStep(
            .deletingUserDocument,
            failureMessage: "プロフィールデータの削除に失敗しました。Firestore Rules の users/{uid} delete を確認してください。",
            onProgress: onProgress
        ) {
            print("[AccountDeletion] deleting users/\(user.id)")
            try await db.collection("users").document(user.id).delete()
            print("[AccountDeletion] deleted users/\(user.id)")
        }

        try await runStep(
            .deletingAuthUser,
            failureMessage: "プロフィールデータは削除済みですが、ログインアカウントの削除に失敗しました。もう一度アカウント削除を実行してください。",
            preservesAuthErrors: true,
            onProgress: onProgress
        ) {
            print("[AccountDeletion] deleting Firebase Auth user \(user.id)")
            try await auth.deleteAccount(password: password)
            print("[AccountDeletion] deleted Firebase Auth user \(user.id)")
        }

        await reportProgress(.completed, onProgress: onProgress)
    }

    private func anonymizeOwnedStickers(userId: String) async throws {
        let stickerSnapshot = try await db.collection("stickers")
            .whereField("authorId", isEqualTo: userId)
            .getDocuments()
        let assetSnapshot = try await db.collection("stickerAssets")
            .whereField("ownerId", isEqualTo: userId)
            .getDocuments()

        var batch = db.batch()
        var writeCount = 0
        for document in stickerSnapshot.documents {
            batch.updateData([
                "authorId": Self.deletedUserAuthorId,
                "authorName": Self.deletedUserDisplayName,
                "authorAvatar": Self.deletedUserAvatar,
                "comment": ""
            ], forDocument: document.reference)
            writeCount += 1
            try await commitIfNeeded(&batch, &writeCount)
        }
        for document in assetSnapshot.documents {
            batch.updateData(["ownerId": Self.deletedUserAuthorId], forDocument: document.reference)
            writeCount += 1
            try await commitIfNeeded(&batch, &writeCount)
        }
        if writeCount > 0 {
            try await batch.commit()
        }
    }

    private func deleteOwnedStickers(userId: String) async throws {
        let stickerSnapshot = try await db.collection("stickers")
            .whereField("authorId", isEqualTo: userId)
            .getDocuments()
        let stickers = stickerSnapshot.documents.map { StickerPost(id: $0.documentID, data: $0.data()) }
        let stickerIds = Set(stickers.map(\.id))
        var diaryIdsByGroup: [String: Set<String>] = [:]
        var groupStickerCounts: [String: Int64] = [:]

        for sticker in stickers where sticker.target == .group {
            diaryIdsByGroup[sticker.groupId, default: []].insert(sticker.diaryId)
            groupStickerCounts[sticker.groupId, default: 0] += 1
        }

        let assetSnapshot = try await db.collection("stickerAssets")
            .whereField("ownerId", isEqualTo: userId)
            .getDocuments()
        var storagePaths = Set<String>()
        for document in assetSnapshot.documents {
            let data = document.data()
            storagePaths.insert(data["storagePath"] as? String ?? "stickerAssets/\(userId)/\(document.documentID).png")
        }
        for sticker in stickers {
            storagePaths.insert("stickerAssets/\(userId)/\(sticker.assetId).png")
        }

        var batch = db.batch()
        var writeCount = 0
        for document in stickerSnapshot.documents {
            batch.deleteDocument(document.reference)
            writeCount += 1
            try await commitIfNeeded(&batch, &writeCount)
        }
        for document in assetSnapshot.documents {
            batch.deleteDocument(document.reference)
            writeCount += 1
            try await commitIfNeeded(&batch, &writeCount)
        }
        for (groupId, count) in groupStickerCounts {
            batch.updateData(["diaryCount": FieldValue.increment(-count)], forDocument: db.collection("groups").document(groupId))
            writeCount += 1
            try await commitIfNeeded(&batch, &writeCount)
        }
        for diaryId in Set(diaryIdsByGroup.values.flatMap { $0 }) {
            let diaryRef = db.collection("diaries").document(diaryId)
            let snapshot = try await diaryRef.getDocument()
            guard let data = snapshot.data(), snapshot.exists else { continue }
            var layouts = data["stickerLayout"] as? [[String: Any]] ?? []
            layouts.removeAll { layout in
                guard let stickerId = layout["stickerId"] as? String else { return false }
                return stickerIds.contains(stickerId)
            }
            batch.updateData(["stickerLayout": layouts, "updatedAt": FieldValue.serverTimestamp()], forDocument: diaryRef)
            writeCount += 1
            try await commitIfNeeded(&batch, &writeCount)
        }
        if writeCount > 0 {
            try await batch.commit()
        }

        for path in storagePaths {
            try? await storage.reference(withPath: path).delete()
        }
    }

    private func deleteSocialData(userId: String) async throws {
        let queries = [
            db.collection("friendships").whereField("userId", isEqualTo: userId),
            db.collection("friendships").whereField("friendId", isEqualTo: userId),
            db.collection("friendRequests").whereField("fromUserId", isEqualTo: userId),
            db.collection("friendRequests").whereField("toUserId", isEqualTo: userId),
            db.collection("stickerReports").whereField("reporterId", isEqualTo: userId),
            db.collection("stickerReports").whereField("reportedAuthorId", isEqualTo: userId),
            db.collection("notifications").whereField("recipientId", isEqualTo: userId),
            db.collection("notifications").whereField("actorId", isEqualTo: userId),
            db.collection("editLocks").whereField("lockedBy", isEqualTo: userId)
        ]

        for query in queries {
            try await deleteDocuments(matching: query)
        }
    }

    private func removeFromGroups(userId: String) async throws {
        let groupSnapshot = try await db.collection("groups")
            .whereField("memberIds", arrayContains: userId)
            .getDocuments()

        for document in groupSnapshot.documents {
            let group = PetankoGroup(id: document.documentID, data: document.data())
            guard let memberIndex = group.memberIds.firstIndex(of: userId) else { continue }
            let remainingMemberIds = group.memberIds.filter { $0 != userId }
            let batch = db.batch()
            batch.deleteDocument(db.collection("groupMembers").document("\(group.id)_\(userId)"))

            if remainingMemberIds.isEmpty {
                batch.deleteDocument(document.reference)
                try await batch.commit()
                try await deleteGroupOwnedData(group: group)
                continue
            }

            var memberNames = group.memberNames
            var memberAvatars = group.memberAvatars
            while memberNames.count < group.memberIds.count { memberNames.append("") }
            while memberAvatars.count < group.memberIds.count { memberAvatars.append("system:person.fill") }
            memberNames.remove(at: memberIndex)
            memberAvatars.remove(at: memberIndex)

            var updateData: [String: Any] = [
                "memberIds": remainingMemberIds,
                "memberNames": memberNames,
                "memberAvatars": memberAvatars
            ]
            if group.ownerId == userId, let nextOwnerId = remainingMemberIds.first {
                updateData["ownerId"] = nextOwnerId
                batch.setData(["role": "owner"], forDocument: db.collection("groupMembers").document("\(group.id)_\(nextOwnerId)"), merge: true)
            }
            batch.updateData(updateData, forDocument: document.reference)
            try await batch.commit()
        }
    }

    private func deleteGroupOwnedData(group: PetankoGroup) async throws {
        try await deleteDocuments(matching: db.collection("diaries").whereField("groupId", isEqualTo: group.id))
        let groupStickers = try await db.collection("stickers")
            .whereField("groupId", isEqualTo: group.id)
            .getDocuments()
        let assetIds = Set(groupStickers.documents.compactMap { $0.data()["assetId"] as? String })
        try await deleteDocuments(documents: groupStickers.documents)
        for assetId in assetIds {
            try? await db.collection("stickerAssets").document(assetId).delete()
            try? await storage.reference(withPath: "stickerAssets/\(group.ownerId)/\(assetId).png").delete()
        }
        if let iconURL = group.iconURL {
            try? await storage.reference(forURL: iconURL).delete()
        }
    }

    private func deleteAccountCollections(userId: String) async throws {
        let blocks = try await db.collection("users").document(userId).collection("blockedUsers").getDocuments()
        try await deleteDocuments(documents: blocks.documents)
    }

    private func deleteInboundBlockReferences(userId: String) async throws {
        do {
            let inboundBlocks = try await db.collectionGroup("blockedUsers")
                .whereField("blockedUserId", isEqualTo: userId)
                .getDocuments()
            try await deleteDocuments(documents: inboundBlocks.documents)
        } catch {
            if error.isPetankoMissingFirestoreIndexError {
                print("[AccountDeletion] skipped inbound blockedUsers cleanup because the collection group index is missing: \(error.localizedDescription)")
                return
            }
            throw error
        }
    }

    private func deleteProfileStorage(user: AppUser) async throws {
        if let avatarURL = user.avatarURL, !avatarURL.isEmpty {
            try? await storage.reference(forURL: avatarURL).delete()
        }
        let profileRoot = storage.reference(withPath: "profilePhotos/\(user.id)")
        let list = try? await listAll(profileRoot)
        for item in list?.items ?? [] {
            try? await item.delete()
        }
    }

    private func deleteDocuments(matching query: Query) async throws {
        let snapshot = try await query.getDocuments()
        try await deleteDocuments(documents: snapshot.documents)
    }

    private func deleteDocuments(documents: [QueryDocumentSnapshot]) async throws {
        var batch = db.batch()
        var writeCount = 0
        for document in documents {
            batch.deleteDocument(document.reference)
            writeCount += 1
            try await commitIfNeeded(&batch, &writeCount)
        }
        if writeCount > 0 {
            try await batch.commit()
        }
    }

    private func commitIfNeeded(_ batch: inout WriteBatch, _ writeCount: inout Int) async throws {
        guard writeCount >= 450 else { return }
        try await batch.commit()
        batch = db.batch()
        writeCount = 0
    }

    private func listAll(_ reference: StorageReference) async throws -> StorageListResult {
        try await withCheckedThrowingContinuation { continuation in
            reference.listAll { result, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let result {
                    continuation.resume(returning: result)
                } else {
                    continuation.resume(throwing: PetankoError.message("保存画像の確認に失敗しました。"))
                }
            }
        }
    }

    private func runStep(
        _ step: AccountDeletionStep,
        failureMessage: String,
        preservesAuthErrors: Bool = false,
        onProgress: @escaping @MainActor (AccountDeletionStep) -> Void,
        operation: () async throws -> Void
    ) async throws {
        await reportProgress(step, onProgress: onProgress)
        do {
            try await operation()
        } catch {
            print("[AccountDeletion] failed at \(step): \(error.localizedDescription)")
            if preservesAuthErrors,
               (error.isPetankoRequiresRecentLoginError || error.isPetankoInvalidPasswordAuthError) {
                throw error
            }
            throw PetankoError.message(failureMessage)
        }
    }

    private func reportProgress(
        _ step: AccountDeletionStep,
        onProgress: @escaping @MainActor (AccountDeletionStep) -> Void
    ) async {
        print("[AccountDeletion] \(step.title)")
        await MainActor.run {
            onProgress(step)
        }
    }
}
