import FirebaseAuth
import FirebaseFirestore
import Foundation

final class AuthService {
    private let db: Firestore

    init(db: Firestore) {
        self.db = db
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
            try await userRef.setData(["email": account.email, "updatedAt": FieldValue.serverTimestamp()], merge: true)
        } else {
            try await userRef.setData(["updatedAt": FieldValue.serverTimestamp()], merge: true)
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

    func signOut() throws {
        try Auth.auth().signOut()
    }
}
