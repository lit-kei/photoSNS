import FirebaseFirestore
import Foundation

final class BlockService {
    private let db: Firestore

    init(db: Firestore) {
        self.db = db
    }

    func observeBlockedUsers(userId: String, onChange: @escaping ([UserBlock], Error?) -> Void) -> ListenerRegistration {
        db.collection("users").document(userId).collection("blockedUsers")
            .addSnapshotListener { snapshot, error in
                if let error {
                    onChange([], error)
                    return
                }

                let blocks = snapshot?.documents
                    .map { UserBlock(id: $0.documentID, data: $0.data()) }
                    .sorted { $0.createdAt > $1.createdAt } ?? []
                onChange(blocks, nil)
            }
    }

    func blockUser(blockedUserId: String, currentUserId: String) async throws {
        guard blockedUserId != currentUserId else {
            throw PetankoError.message("自分自身はブロックできません。")
        }

        let blockRef = blockDocument(blockerId: currentUserId, blockedUserId: blockedUserId)
        let batch = db.batch()
        batch.setData(
            UserBlock(id: blockedUserId, blockerId: currentUserId, blockedUserId: blockedUserId).dictionary,
            forDocument: blockRef,
            merge: true
        )

        let friendshipRefs = [
            db.collection("friendships").document("\(currentUserId)_\(blockedUserId)"),
            db.collection("friendships").document("\(blockedUserId)_\(currentUserId)")
        ]
        for ref in friendshipRefs {
            let snapshot = try await ref.getDocument()
            guard snapshot.exists,
                  let data = snapshot.data(),
                  data["userId"] as? String == currentUserId || data["friendId"] as? String == currentUserId else {
                continue
            }
            batch.deleteDocument(ref)
        }

        let requestRefs = [
            db.collection("friendRequests").document("\(currentUserId)_\(blockedUserId)"),
            db.collection("friendRequests").document("\(blockedUserId)_\(currentUserId)")
        ]
        for ref in requestRefs {
            let snapshot = try await ref.getDocument()
            guard snapshot.exists,
                  let data = snapshot.data(),
                  data["fromUserId"] as? String == currentUserId || data["toUserId"] as? String == currentUserId else {
                continue
            }
            batch.deleteDocument(ref)
        }

        try await batch.commit()
    }

    func unblockUser(blockedUserId: String, currentUserId: String) async throws {
        guard blockedUserId != currentUserId else { return }
        try await blockDocument(blockerId: currentUserId, blockedUserId: blockedUserId).delete()
    }

    func isBlockedBetween(_ firstUserId: String, _ secondUserId: String) async throws -> Bool {
        guard firstUserId != secondUserId else { return false }
        async let firstBlocksSecond = blockDocument(blockerId: firstUserId, blockedUserId: secondUserId).getDocument()
        async let secondBlocksFirst = blockDocument(blockerId: secondUserId, blockedUserId: firstUserId).getDocument()
        let firstSnapshot = try await firstBlocksSecond
        let secondSnapshot = try await secondBlocksFirst
        return firstSnapshot.exists || secondSnapshot.exists
    }

    private func blockDocument(blockerId: String, blockedUserId: String) -> DocumentReference {
        db.collection("users")
            .document(blockerId)
            .collection("blockedUsers")
            .document(blockedUserId)
    }
}
