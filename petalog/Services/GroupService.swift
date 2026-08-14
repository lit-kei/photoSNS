import FirebaseFirestore
import Foundation

final class GroupService {
    private let db: Firestore

    init(db: Firestore) {
        self.db = db
    }

    func observeMyGroups(userId: String, onChange: @escaping ([PetalogGroup], Error?) -> Void) -> ListenerRegistration {
        db.collection("groups")
            .whereField("memberIds", arrayContains: userId)
            .addSnapshotListener { snapshot, error in
                if let error {
                    onChange([], error)
                    return
                }

                let groups = snapshot?.documents
                    .map { PetalogGroup(id: $0.documentID, data: $0.data()) }
                    .sorted { $0.createdAt > $1.createdAt } ?? []
                onChange(groups, nil)
            }
    }

    func createGroup(name: String, icon: String, currentUser: AppUser) async throws -> PetalogGroup {
        let groupRef = db.collection("groups").document()
        let inviteCode = Self.makeInviteCode()
        let group = PetalogGroup(
            id: groupRef.documentID,
            name: name.trimmedForPetalog,
            icon: icon,
            inviteCode: inviteCode,
            ownerId: currentUser.id,
            memberIds: [currentUser.id],
            memberNames: [currentUser.displayName],
            memberAvatars: [currentUser.avatar]
        )

        let batch = db.batch()
        batch.setData(group.dictionary, forDocument: groupRef)
        batch.setData(
            [
                "groupId": group.id,
                "userId": currentUser.id,
                "displayName": currentUser.displayName,
                "avatar": currentUser.avatar,
                "role": "owner",
                "joinedAt": FieldValue.serverTimestamp()
            ],
            forDocument: db.collection("groupMembers").document("\(group.id)_\(currentUser.id)")
        )
        try await batch.commit()
        return group
    }

    func joinGroup(inviteCode: String, currentUser: AppUser) async throws {
        let code = inviteCode.trimmedForPetalog.uppercased()
        let snapshot = try await db.collection("groups")
            .whereField("inviteCode", isEqualTo: code)
            .limit(to: 1)
            .getDocuments()

        guard let document = snapshot.documents.first else {
            throw PetalogError.message("招待コードに一致するグループが見つかりません。")
        }

        let group = PetalogGroup(id: document.documentID, data: document.data())
        let batch = db.batch()
        batch.updateData(
            [
                "memberIds": FieldValue.arrayUnion([currentUser.id]),
                "memberNames": FieldValue.arrayUnion([currentUser.displayName]),
                "memberAvatars": FieldValue.arrayUnion([currentUser.avatar])
            ],
            forDocument: document.reference
        )
        batch.setData(
            [
                "groupId": group.id,
                "userId": currentUser.id,
                "displayName": currentUser.displayName,
                "avatar": currentUser.avatar,
                "role": "member",
                "joinedAt": FieldValue.serverTimestamp()
            ],
            forDocument: db.collection("groupMembers").document("\(group.id)_\(currentUser.id)"),
            merge: true
        )
        try await batch.commit()
    }

    private static func makeInviteCode() -> String {
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<6).compactMap { _ in alphabet.randomElement() })
    }
}
