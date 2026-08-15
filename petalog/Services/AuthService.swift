import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import Foundation
import UIKit

final class AuthService {
    private let db: Firestore
    private let storage: Storage

    init(db: Firestore, storage: Storage) {
        self.db = db
        self.storage = storage
    }

    func currentAccount() -> AuthenticatedAccount? {
        guard let user = Auth.auth().currentUser, !user.isAnonymous else { return nil }
        return AuthenticatedAccount(uid: user.uid, email: user.email ?? "")
    }

    func signIn(email: String, password: String) async throws -> AuthenticatedAccount {
        let result = try await Auth.auth().signIn(withEmail: email.trimmedForPetalog, password: password)
        return AuthenticatedAccount(uid: result.user.uid, email: result.user.email ?? email.trimmedForPetalog)
    }

    func createAccount(email: String, password: String) async throws -> AuthenticatedAccount {
        let result = try await Auth.auth().createUser(withEmail: email.trimmedForPetalog, password: password)
        return AuthenticatedAccount(uid: result.user.uid, email: result.user.email ?? email.trimmedForPetalog)
    }

    func fetchUser(account: AuthenticatedAccount) async throws -> AppUser? {
        let userRef = db.collection("users").document(account.uid)
        let snapshot = try await userRef.getDocument()
        guard let data = snapshot.data(), snapshot.exists else { return nil }
        var user = AppUser(id: account.uid, data: data)
        if user.email.isEmpty {
            user.email = account.email
            try await userRef.setData(["email": account.email, "normalizedEmail": account.email.lowercased(), "updatedAt": FieldValue.serverTimestamp()], merge: true)
        } else {
            try await userRef.setData(["normalizedEmail": user.email.lowercased(), "updatedAt": FieldValue.serverTimestamp()], merge: true)
        }
        return user
    }

    func createProfile(account: AuthenticatedAccount, displayName: String, avatar: String) async throws -> AppUser {
        let name = displayName.trimmedForPetalog
        guard !name.isEmpty else {
            throw PetalogError.message("ユーザー名を入力してください。")
        }

        let user = AppUser(id: account.uid, email: account.email, displayName: name, avatar: avatar)
        try await db.collection("users").document(account.uid).setData(user.dictionary, merge: true)
        return user
    }

    func updateProfile(user: AppUser) async throws {
        try await db.collection("users").document(user.id).setData(user.dictionary, merge: true)
    }

    func uploadProfileImage(userId: String, imageData: Data) async throws -> URL {
        let uploadData = imageData.petalogOptimizedJPEG(
            maxDimension: 1_024,
            quality: 0.80,
            maximumBytes: 700_000
        )

        let ref = storage.reference(withPath: "profilePhotos/\(userId)/\(UUID().uuidString).jpg")
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
                    continuation.resume(throwing: PetalogError.message("プロフィール写真の保存に失敗しました。"))
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

    func deleteProfileImage(at urlString: String) async {
        guard let url = URL(string: urlString) else { return }
        try? await storage.reference(forURL: urlString).delete()
        await RemoteImageCache.shared.remove(for: url)
    }

    func signOut() throws {
        try Auth.auth().signOut()
    }
}
