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

    func addFriend(email: String, currentUser: AppUser) async throws {
        let trimmedEmail = email.trimmedForPetalog
        let normalizedEmail = trimmedEmail.lowercased()
        guard !normalizedEmail.isEmpty else {
            throw PetalogError.message("友達のメールアドレスを入力してください。")
        }
        guard normalizedEmail != currentUser.email.lowercased() else {
            throw PetalogError.message("自分自身は追加できません。")
        }

        let snapshot = try await db.collection("users")
            .whereField("normalizedEmail", isEqualTo: normalizedEmail)
            .limit(to: 1)
            .getDocuments()

        let document: QueryDocumentSnapshot?
        if let foundDocument = snapshot.documents.first {
            document = foundDocument
        } else {
            let legacySnapshot = try await db.collection("users")
                .whereField("email", isEqualTo: trimmedEmail)
                .limit(to: 1)
                .getDocuments()
            document = legacySnapshot.documents.first
        }

        guard let document else {
            throw PetalogError.message("このメールアドレスのユーザーが見つかりません。")
        }

        let friendUser = AppUser(id: document.documentID, data: document.data())
        let currentFriend = AppFriend(
            id: "\(currentUser.id)_\(friendUser.id)",
            userId: currentUser.id,
            friendId: friendUser.id,
            friendName: friendUser.displayName,
            friendEmail: friendUser.email,
            friendAvatar: friendUser.avatar,
            friendAvatarURL: friendUser.avatarURL
        )
        let reverseFriend = AppFriend(
            id: "\(friendUser.id)_\(currentUser.id)",
            userId: friendUser.id,
            friendId: currentUser.id,
            friendName: currentUser.displayName,
            friendEmail: currentUser.email,
            friendAvatar: currentUser.avatar,
            friendAvatarURL: currentUser.avatarURL
        )

        let batch = db.batch()
        batch.setData(
            currentFriend.dictionary,
            forDocument: db.collection("friendships").document(currentFriend.id),
            merge: true
        )
        batch.setData(
            reverseFriend.dictionary,
            forDocument: db.collection("friendships").document(reverseFriend.id),
            merge: true
        )
        try await batch.commit()
    }
}
