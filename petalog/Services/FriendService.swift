import FirebaseFirestore
import Foundation

final class FriendService {
    private let db: Firestore

    init(db: Firestore) {
        self.db = db
    }

    func observeFriends(userId: String, onChange: @escaping ([AppFriend], Error?) -> Void) -> ListenerRegistration {
        db.collection("friendships")
            .whereField("userId", isEqualTo: userId)
            .addSnapshotListener { snapshot, error in
                if let error {
                    onChange([], error)
                    return
                }

                let friends = snapshot?.documents
                    .map { AppFriend(id: $0.documentID, data: $0.data()) }
                    .sorted { $0.createdAt > $1.createdAt } ?? []
                onChange(friends, nil)
            }
    }

    func observeIncomingRequests(userId: String, onChange: @escaping ([FriendRequest], Error?) -> Void) -> ListenerRegistration {
        observeRequests(field: "toUserId", userId: userId, onChange: onChange)
    }

    func observeOutgoingRequests(userId: String, onChange: @escaping ([FriendRequest], Error?) -> Void) -> ListenerRegistration {
        observeRequests(field: "fromUserId", userId: userId, onChange: onChange)
    }

    func findUser(email: String) async throws -> AppUser? {
        let trimmedEmail = email.trimmedForPetalog
        let normalizedEmail = trimmedEmail.lowercased()
        guard !normalizedEmail.isEmpty else { return nil }

        let snapshot = try await db.collection("users")
            .whereField("normalizedEmail", isEqualTo: normalizedEmail)
            .limit(to: 1)
            .getDocuments()
        if let document = snapshot.documents.first {
            return AppUser(id: document.documentID, data: document.data())
        }

        let legacySnapshot = try await db.collection("users")
            .whereField("email", isEqualTo: trimmedEmail)
            .limit(to: 1)
            .getDocuments()
        guard let document = legacySnapshot.documents.first else { return nil }
        return AppUser(id: document.documentID, data: document.data())
    }

    func fetchUser(userId: String) async throws -> AppUser? {
        let snapshot = try await db.collection("users").document(userId).getDocument()
        guard let data = snapshot.data(), snapshot.exists else { return nil }
        return AppUser(id: snapshot.documentID, data: data)
    }

    func sendRequest(to targetUser: AppUser, currentUser: AppUser) async throws {
        guard targetUser.id != currentUser.id else {
            throw PetalogError.message("自分自身には申請できません。")
        }

        let friendshipId = "\(currentUser.id)_\(targetUser.id)"
        let friendship = try await db.collection("friendships").document(friendshipId).getDocument()
        guard !friendship.exists else {
            throw PetalogError.message("すでに友達です。")
        }

        let newRequestId = makeRequestId(from: currentUser.id, to: targetUser.id)
        let reverseRequestId = makeRequestId(from: targetUser.id, to: currentUser.id)
        let requestSnapshot = try await db.collection("friendRequests").document(newRequestId).getDocument()
        let reverseSnapshot = try await db.collection("friendRequests").document(reverseRequestId).getDocument()
        guard requestSnapshot.data()?["status"] as? String != "pending" else {
            throw PetalogError.message("すでに申請を送っています。")
        }
        guard reverseSnapshot.data()?["status"] as? String != "pending" else {
            throw PetalogError.message("相手から申請が届いています。受信申請から承認できます。")
        }

        let request = FriendRequest(
            id: newRequestId,
            fromUserId: currentUser.id,
            fromName: currentUser.displayName,
            fromAvatar: currentUser.avatar,
            fromAvatarURL: currentUser.avatarURL,
            toUserId: targetUser.id,
            toName: targetUser.displayName,
            toAvatar: targetUser.avatar,
            toAvatarURL: targetUser.avatarURL
        )
        try await db.collection("friendRequests").document(newRequestId).setData(request.dictionary, merge: true)
    }

    func acceptRequest(_ request: FriendRequest, currentUser: AppUser) async throws {
        guard request.toUserId == currentUser.id else { return }
        let fromUser = try await fetchUser(userId: request.fromUserId) ?? AppUser(id: request.fromUserId, displayName: request.fromName, avatar: request.fromAvatar, avatarURL: request.fromAvatarURL)

        let currentFriend = AppFriend(
            id: "\(currentUser.id)_\(fromUser.id)",
            userId: currentUser.id,
            friendId: fromUser.id,
            friendName: fromUser.displayName,
            friendEmail: "",
            friendAvatar: fromUser.avatar,
            friendAvatarURL: fromUser.avatarURL
        )
        let reverseFriend = AppFriend(
            id: "\(fromUser.id)_\(currentUser.id)",
            userId: fromUser.id,
            friendId: currentUser.id,
            friendName: currentUser.displayName,
            friendEmail: "",
            friendAvatar: currentUser.avatar,
            friendAvatarURL: currentUser.avatarURL
        )

        let batch = db.batch()
        batch.setData(currentFriend.dictionary, forDocument: db.collection("friendships").document(currentFriend.id), merge: true)
        batch.setData(reverseFriend.dictionary, forDocument: db.collection("friendships").document(reverseFriend.id), merge: true)
        batch.setData(["status": "accepted", "updatedAt": FieldValue.serverTimestamp()], forDocument: db.collection("friendRequests").document(request.id), merge: true)
        try await batch.commit()
    }

    func rejectRequest(_ request: FriendRequest, currentUser: AppUser) async throws {
        guard request.toUserId == currentUser.id else { return }
        try await db.collection("friendRequests").document(request.id).setData(
            ["status": "rejected", "updatedAt": FieldValue.serverTimestamp()],
            merge: true
        )
    }

    private func observeRequests(field: String, userId: String, onChange: @escaping ([FriendRequest], Error?) -> Void) -> ListenerRegistration {
        db.collection("friendRequests")
            .whereField(field, isEqualTo: userId)
            .addSnapshotListener { snapshot, error in
                if let error {
                    onChange([], error)
                    return
                }

                let requests = snapshot?.documents
                    .map { FriendRequest(id: $0.documentID, data: $0.data()) }
                    .filter { $0.status == "pending" }
                    .sorted { $0.createdAt > $1.createdAt } ?? []
                onChange(requests, nil)
            }
    }

    private func makeRequestId(from fromUserId: String, to toUserId: String) -> String {
        "\(fromUserId)_\(toUserId)"
    }
}
