//
//  FirebaseServices.swift
//  petalog
//

import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import Foundation
import UIKit

final class AppServices {
    static let shared = AppServices()

    let db = Firestore.firestore()
    let storage = Storage.storage()

    lazy var auth = AuthService(db: db)
    lazy var groups = GroupService(db: db)
    lazy var diaries = DiaryService(db: db)
    lazy var stickers = StickerService(db: db, storage: storage)

    private init() {}
}

final class AuthService {
    private let db: Firestore

    init(db: Firestore) {
        self.db = db
    }

    func signInAnonymouslyIfNeeded() async throws -> AppUser {
        let firebaseUser: FirebaseAuth.User
        if let currentUser = Auth.auth().currentUser {
            firebaseUser = currentUser
        } else {
            firebaseUser = try await Auth.auth().signInAnonymously().user
        }

        let userRef = db.collection("users").document(firebaseUser.uid)
        let snapshot = try await userRef.getDocument()
        if let data = snapshot.data(), snapshot.exists {
            let user = AppUser(id: firebaseUser.uid, data: data)
            try await userRef.setData(["updatedAt": FieldValue.serverTimestamp()], merge: true)
            return user
        }

        let suffix = String(firebaseUser.uid.prefix(4)).uppercased()
        let user = AppUser(id: firebaseUser.uid, displayName: "petalog \(suffix)", avatar: "🙂")
        try await userRef.setData(user.dictionary, merge: true)
        return user
    }

    func updateProfile(user: AppUser) async throws {
        try await db.collection("users").document(user.id).setData(user.dictionary, merge: true)
    }
}

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

final class DiaryService {
    private let db: Firestore

    init(db: Firestore) {
        self.db = db
    }

    func diaryId(groupId: String, dateKey: String) -> String {
        "\(groupId)_\(dateKey)"
    }

    func ensureTodayDiary(group: PetalogGroup, dateKey: String) async throws -> DiaryPage {
        let id = diaryId(groupId: group.id, dateKey: dateKey)
        let ref = db.collection("diaries").document(id)
        let snapshot = try await ref.getDocument()
        if let data = snapshot.data(), snapshot.exists {
            return DiaryPage(id: id, data: data)
        }

        let page = DiaryPage(id: id, groupId: group.id, dateKey: dateKey, title: Date().petalogShortTitle)
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

    func acquireEditLock(groupId: String, diaryId: String, user: AppUser) async throws -> Bool {
        let ref = db.collection("editLocks").document(diaryId)
        let snapshot = try await ref.getDocument()
        if let data = snapshot.data(),
           let lockedBy = data["lockedBy"] as? String,
           lockedBy != user.id,
           let expiresAt = data["expiresAt"] as? Timestamp,
           expiresAt.dateValue() > Date() {
            return false
        }

        try await ref.setData(
            [
                "groupId": groupId,
                "diaryId": diaryId,
                "lockedBy": user.id,
                "lockedByName": user.displayName,
                "expiresAt": Timestamp(date: Date().addingTimeInterval(10 * 60)),
                "updatedAt": FieldValue.serverTimestamp()
            ],
            merge: true
        )
        return true
    }

    func releaseEditLock(diaryId: String, userId: String) async throws {
        let ref = db.collection("editLocks").document(diaryId)
        let snapshot = try await ref.getDocument()
        guard snapshot.data()?["lockedBy"] as? String == userId else { return }
        try await ref.delete()
    }
}

final class StickerService {
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

    func uploadSticker(originalImage: UIImage, stickerPNG: Data, draft: StickerDraft, group: PetalogGroup, user: AppUser) async throws -> StickerPost {
        guard let originalData = originalImage.jpegData(compressionQuality: 0.86) else {
            throw PetalogError.message("元写真の保存データを作れませんでした。")
        }

        let stickerId = UUID().uuidString
        let dateKey = Date().petalogDateKey
        let diaryId = "\(group.id)_\(dateKey)"
        let originalPath = "originalPhotos/\(user.id)/\(stickerId).jpg"
        let stickerPath = "stickers/\(group.id)/\(diaryId)/\(stickerId).png"

        let originalURL = try await upload(data: originalData, path: originalPath, contentType: "image/jpeg")
        let stickerURL = try await upload(data: stickerPNG, path: stickerPath, contentType: "image/png")

        let layout = StickerLayout(
            stickerId: stickerId,
            x: Double.random(in: -80...80),
            y: Double.random(in: -140...140),
            scale: Double.random(in: 0.86...1.12),
            rotation: Double.random(in: -13...13),
            zIndex: Int(Date().timeIntervalSince1970)
        )

        let post = StickerPost(
            id: stickerId,
            groupId: group.id,
            diaryId: diaryId,
            dateKey: dateKey,
            authorId: user.id,
            authorName: user.displayName,
            authorAvatar: user.avatar,
            comment: draft.comment.trimmedForPetalog,
            shape: draft.shape,
            decoration: draft.decoration,
            originalPhotoURL: originalURL.absoluteString,
            stickerImageURL: stickerURL.absoluteString,
            layout: layout
        )

        let diary = DiaryPage(id: diaryId, groupId: group.id, dateKey: dateKey, title: Date().petalogShortTitle)
        let batch = db.batch()
        batch.setData(diary.dictionary, forDocument: db.collection("diaries").document(diaryId), merge: true)
        batch.setData(post.dictionary, forDocument: db.collection("stickers").document(stickerId))
        batch.updateData(["diaryCount": FieldValue.increment(Int64(1))], forDocument: db.collection("groups").document(group.id))
        try await batch.commit()
        return post
    }

    private func upload(data: Data, path: String, contentType: String) async throws -> URL {
        let ref = storage.reference(withPath: path)
        let metadata = StorageMetadata()
        metadata.contentType = contentType

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

struct StickerDraft: Hashable {
    var shape: StickerShapeOption = .circle
    var decoration: StickerDecoration = .sparkle
    var scale: Double = 1
    var rotation: Double = 0
    var offset: CGSize = .zero
    var comment: String = ""
}

enum PetalogError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case .message(let message): message
        }
    }
}
