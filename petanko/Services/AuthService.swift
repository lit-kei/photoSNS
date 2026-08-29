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

    func needsPasswordForAccountDeletion() -> Bool {
        Auth.auth().currentUser?.providerData.contains { $0.providerID == EmailAuthProviderID } == true
    }

    func signIn(email: String, password: String) async throws -> AuthenticatedAccount {
        let result = try await Auth.auth().signIn(withEmail: email.trimmedForPetanko, password: password)
        return AuthenticatedAccount(uid: result.user.uid, email: result.user.email ?? email.trimmedForPetanko)
    }

    func createAccount(email: String, password: String) async throws -> AuthenticatedAccount {
        let result = try await Auth.auth().createUser(withEmail: email.trimmedForPetanko, password: password)
        return AuthenticatedAccount(uid: result.user.uid, email: result.user.email ?? email.trimmedForPetanko)
    }

    func fetchUser(account: AuthenticatedAccount) async throws -> AppUser? {
        let userRef = db.collection("users").document(account.uid)
        let snapshot = try await userRef.getDocument()
        guard let data = snapshot.data(), snapshot.exists else { return nil }
        var user = AppUser(id: account.uid, data: data)
        var updateData: [String: Any] = [
            "playerId": user.playerId,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        if user.email.isEmpty {
            user.email = account.email
            updateData["email"] = account.email
            updateData["normalizedEmail"] = account.email.lowercased()
        } else {
            updateData["normalizedEmail"] = user.email.lowercased()
        }
        try await userRef.setData(updateData, merge: true)
        return user
    }

    func createProfile(account: AuthenticatedAccount, displayName: String, avatar: String, termsAcceptedAt: Date? = nil) async throws -> AppUser {
        let name = displayName.trimmedForPetanko
        guard !name.isEmpty else {
            throw PetankoError.message("ユーザー名を入力してください。")
        }

        let user = AppUser(id: account.uid, email: account.email, displayName: name, avatar: avatar, termsAcceptedAt: termsAcceptedAt)
        try await db.collection("users").document(account.uid).setData(user.dictionary, merge: true)
        return user
    }

    func updateProfile(user: AppUser) async throws {
        try await db.collection("users").document(user.id).setData(user.dictionary, merge: true)
    }

    func uploadProfileImage(userId: String, imageData: Data) async throws -> URL {
        let uploadData = imageData.petankoOptimizedJPEG(
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
                    continuation.resume(throwing: PetankoError.message("プロフィール写真の保存に失敗しました。"))
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

    func reauthenticate(password: String) async throws {
        guard let user = Auth.auth().currentUser,
              let email = user.email else {
            throw PetankoError.message("ログイン情報を確認できませんでした。")
        }
        let credential = EmailAuthProvider.credential(withEmail: email, password: password)
        try await user.reauthenticate(with: credential)
    }

    func deleteAccount(password: String?) async throws {
        if let password, !password.isEmpty {
            try await reauthenticate(password: password)
        }
        guard let user = Auth.auth().currentUser else {
            throw PetankoError.message("ログイン情報を確認できませんでした。")
        }
        try await user.delete()
    }

    func signOut() throws {
        try Auth.auth().signOut()
    }
}
