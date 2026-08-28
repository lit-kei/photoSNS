import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import Foundation
import UIKit

final class GroupService {
    private let db: Firestore
    private let storage: Storage

    init(db: Firestore, storage: Storage) {
        self.db = db
        self.storage = storage
    }

    func observeMyGroups(userId: String, onChange: @escaping ([PetankoGroup], Error?) -> Void) -> ListenerRegistration {
        db.collection("groups")
            .whereField("memberIds", arrayContains: userId)
            .addSnapshotListener { snapshot, error in
                if let error {
                    onChange([], error)
                    return
                }

                let groups = snapshot?.documents
                    .map { PetankoGroup(id: $0.documentID, data: $0.data()) }
                    .sorted { $0.createdAt > $1.createdAt } ?? []
                onChange(groups, nil)
            }
    }

    func observeMyGroupReadStates(
        userId: String,
        onChange: @escaping ([String: Date], Error?) -> Void
    ) -> ListenerRegistration {
        db.collection("groupMembers")
            .whereField("userId", isEqualTo: userId)
            .addSnapshotListener { snapshot, error in
                if let error {
                    onChange([:], error)
                    return
                }

                let states = snapshot?.documents.reduce(into: [String: Date]()) { result, document in
                    let data = document.data()
                    guard let groupId = data["groupId"] as? String,
                          let lastReadAt = data["lastReadAt"] as? Timestamp else { return }
                    result[groupId] = lastReadAt.dateValue()
                } ?? [:]
                onChange(states, nil)
            }
    }

    func initializeGroupReadState(groupId: String, userId: String) async throws {
        try await saveGroupReadState(groupId: groupId, userId: userId, at: Date())
    }

    func markGroupAsRead(groupId: String, userId: String, at date: Date) async throws {
        try await saveGroupReadState(groupId: groupId, userId: userId, at: date)
    }

    func createGroup(name: String, icon: String, iconImageData: Data? = nil, currentUser: AppUser) async throws -> PetankoGroup {
        guard let authUserId = Auth.auth().currentUser?.uid else {
            throw PetankoError.message("ログイン情報を確認できませんでした。")
        }

        let groupRef = db.collection("groups").document()
        let inviteCode = Self.makeInviteCode()
        let iconURL: String?
        if let iconImageData {
            iconURL = try await uploadGroupIcon(groupId: groupRef.documentID, imageData: iconImageData).absoluteString
        } else {
            iconURL = nil
        }

        let group = PetankoGroup(
            id: groupRef.documentID,
            name: name.trimmedForPetanko,
            icon: icon,
            iconURL: iconURL,
            inviteCode: inviteCode,
            ownerId: authUserId,
            memberIds: [authUserId],
            memberNames: [currentUser.displayName],
            memberAvatars: [currentUser.memberAvatarValue]
        )

        let batch = db.batch()
        batch.setData(group.dictionary, forDocument: groupRef)
        batch.setData(
            [
                "groupId": group.id,
                "userId": authUserId,
                "displayName": currentUser.displayName,
                "avatar": currentUser.avatar,
                "avatarURL": currentUser.avatarURL ?? "",
                "role": "owner",
                "lastReadAt": Timestamp(date: Date()),
                "joinedAt": FieldValue.serverTimestamp()
            ],
            forDocument: db.collection("groupMembers").document("\(group.id)_\(authUserId)")
        )
        do {
            try await batch.commit()
        } catch {
            if let iconURL {
                await deleteGroupIcon(at: iconURL)
            }
            throw error
        }
        return group
    }

    func findGroup(inviteCode: String) async throws -> PetankoGroup? {
        let code = inviteCode.trimmedForPetanko.uppercased()
        guard !code.isEmpty else { return nil }

        let snapshot = try await db.collection("groups")
            .whereField("inviteCode", isEqualTo: code)
            .limit(to: 1)
            .getDocuments()

        guard let document = snapshot.documents.first else { return nil }
        return PetankoGroup(id: document.documentID, data: document.data())
    }

    func joinGroup(inviteCode: String, currentUser: AppUser) async throws {
        guard let authUserId = Auth.auth().currentUser?.uid else {
            throw PetankoError.message("ログイン情報を確認できませんでした。")
        }

        let code = inviteCode.trimmedForPetanko.uppercased()
        let snapshot = try await db.collection("groups")
            .whereField("inviteCode", isEqualTo: code)
            .limit(to: 1)
            .getDocuments()

        guard let document = snapshot.documents.first else {
            throw PetankoError.message("招待コードに一致するグループが見つかりません。")
        }

        let group = PetankoGroup(id: document.documentID, data: document.data())
        guard !group.memberIds.contains(authUserId) else {
            throw PetankoError.message("すでにこのグループに参加しています。")
        }

        let batch = db.batch()
        var memberNames = group.memberNames
        var memberAvatars = group.memberAvatars
        while memberNames.count < group.memberIds.count { memberNames.append("") }
        while memberAvatars.count < group.memberIds.count { memberAvatars.append("system:person.fill") }
        memberNames.append(currentUser.displayName)
        memberAvatars.append(currentUser.memberAvatarValue)
        batch.updateData(
            [
                "memberIds": FieldValue.arrayUnion([authUserId]),
                "memberNames": memberNames,
                "memberAvatars": memberAvatars
            ],
            forDocument: document.reference
        )
        batch.setData(
            [
                "groupId": group.id,
                "userId": authUserId,
                "displayName": currentUser.displayName,
                "avatar": currentUser.avatar,
                "avatarURL": currentUser.avatarURL ?? "",
                "role": "member",
                "lastReadAt": Timestamp(date: Date()),
                "joinedAt": FieldValue.serverTimestamp()
            ],
            forDocument: db.collection("groupMembers").document("\(group.id)_\(authUserId)"),
            merge: true
        )

        for memberId in group.memberIds where memberId != authUserId {
            let notificationRef = db.collection("notifications").document()
            batch.setData(
                [
                    "recipientId": memberId,
                    "type": "group_joined",
                    "groupId": group.id,
                    "groupName": group.name,
                    "actorId": authUserId,
                    "actorName": currentUser.displayName,
                    "message": "\(currentUser.displayName)さんが\(group.name)に参加しました。",
                    "isRead": false,
                    "createdAt": FieldValue.serverTimestamp()
                ],
                forDocument: notificationRef
            )
        }
        try await batch.commit()
    }

    /// Repairs missing avatar entries and keeps the parallel member arrays in
    /// existing group documents aligned with `memberIds`.
    func syncMemberProfile(_ user: AppUser) async throws {
        let snapshot = try await db.collection("groups")
            .whereField("memberIds", arrayContains: user.id)
            .getDocuments()
        guard !snapshot.documents.isEmpty else { return }

        let batch = db.batch()
        for document in snapshot.documents {
            let data = document.data()
            let memberIds = data["memberIds"] as? [String] ?? []
            guard let memberIndex = memberIds.firstIndex(of: user.id) else { continue }

            var memberNames = data["memberNames"] as? [String] ?? []
            var memberAvatars = data["memberAvatars"] as? [String] ?? []
            while memberNames.count < memberIds.count { memberNames.append("") }
            while memberAvatars.count < memberIds.count { memberAvatars.append("system:person.fill") }
            memberNames[memberIndex] = user.displayName
            memberAvatars[memberIndex] = user.memberAvatarValue

            batch.updateData(
                [
                    "memberNames": memberNames,
                    "memberAvatars": memberAvatars
                ],
                forDocument: document.reference
            )
            batch.setData(
                [
                    "groupId": document.documentID,
                    "userId": user.id,
                    "displayName": user.displayName,
                    "avatar": user.avatar,
                    "avatarURL": user.avatarURL ?? ""
                ],
                forDocument: db.collection("groupMembers").document("\(document.documentID)_\(user.id)"),
                merge: true
            )
        }
        try await batch.commit()
    }

    func updateGroup(group: PetankoGroup, name: String, icon: String, iconImageData: Data? = nil) async throws {
        let trimmedName = name.trimmedForPetanko
        guard !trimmedName.isEmpty else {
            throw PetankoError.message("グループ名を入力してください。")
        }

        var data: [String: Any] = [
            "name": trimmedName,
            "icon": icon
        ]

        var uploadedIconURL: URL?
        if let iconImageData {
            let iconURL = try await uploadGroupIcon(groupId: group.id, imageData: iconImageData)
            uploadedIconURL = iconURL
            data["iconURL"] = iconURL.absoluteString
        }

        do {
            try await db.collection("groups").document(group.id).setData(data, merge: true)
        } catch {
            if let uploadedIconURL {
                await deleteGroupIcon(at: uploadedIconURL.absoluteString)
            }
            throw error
        }

        if let oldIconURL = group.iconURL,
           let uploadedIconURL,
           oldIconURL != uploadedIconURL.absoluteString {
            await deleteGroupIcon(at: oldIconURL)
        }
    }

    func leaveGroup(_ group: PetankoGroup, currentUser: AppUser) async throws {
        guard let memberIndex = group.memberIds.firstIndex(of: currentUser.id) else { return }

        let groupRef = db.collection("groups").document(group.id)
        let memberRef = db.collection("groupMembers").document("\(group.id)_\(currentUser.id)")
        let remainingMemberIds = group.memberIds.filter { $0 != currentUser.id }
        let batch = db.batch()

        if remainingMemberIds.isEmpty {
            batch.deleteDocument(groupRef)
            batch.deleteDocument(memberRef)
            try await batch.commit()
            if let iconURL = group.iconURL {
                await deleteGroupIcon(at: iconURL)
            }
            return
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

        if group.ownerId == currentUser.id, let nextOwnerId = remainingMemberIds.first {
            updateData["ownerId"] = nextOwnerId
            batch.setData(
                ["role": "owner"],
                forDocument: db.collection("groupMembers").document("\(group.id)_\(nextOwnerId)"),
                merge: true
            )
        }

        batch.updateData(updateData, forDocument: groupRef)
        batch.deleteDocument(memberRef)
        try await batch.commit()
    }

    private func saveGroupReadState(groupId: String, userId: String, at date: Date) async throws {
        try await db.collection("groupMembers")
            .document("\(groupId)_\(userId)")
            .setData(
                [
                    "groupId": groupId,
                    "userId": userId,
                    "lastReadAt": Timestamp(date: date)
                ],
                merge: true
            )
    }

    private func uploadGroupIcon(groupId: String, imageData: Data) async throws -> URL {
        let uploadData = imageData.petankoOptimizedJPEG(
            maxDimension: 1_024,
            quality: 0.80,
            maximumBytes: 700_000
        )

        let ref = storage.reference(withPath: "groupIcons/\(groupId)/\(UUID().uuidString).jpg")
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
                    continuation.resume(throwing: PetankoError.message("グループアイコンの保存に失敗しました。"))
                }
            }
        }

        let url: URL
        do {
            url = try await ref.downloadURL()
        } catch {
            try? await ref.delete()
            throw error
        }
        Task { await RemoteImageCache.shared.store(data: uploadData, for: url) }
        return url
    }

    private func deleteGroupIcon(at urlString: String) async {
        guard let url = URL(string: urlString) else { return }
        try? await storage.reference(forURL: urlString).delete()
        await RemoteImageCache.shared.remove(for: url)
    }

    private static func makeInviteCode() -> String {
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<6).compactMap { _ in alphabet.randomElement() })
    }
}
