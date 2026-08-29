import FirebaseFirestore
import FirebaseAuth
import Foundation

enum PetankoError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case .message(let message): message
        }
    }
}

extension Error {
    var isPetankoOfflineFirestoreError: Bool {
        let nsError = self as NSError
        return nsError.code == FirestoreErrorCode.unavailable.rawValue
            || nsError.localizedDescription.localizedCaseInsensitiveContains("client is offline")
    }

    var isPetankoPermissionDeniedFirestoreError: Bool {
        let nsError = self as NSError
        return nsError.domain == FirestoreErrorDomain
            && nsError.code == FirestoreErrorCode.permissionDenied.rawValue
    }

    var isPetankoMissingFirestoreIndexError: Bool {
        let nsError = self as NSError
        return nsError.domain == FirestoreErrorDomain
            && nsError.localizedDescription.localizedCaseInsensitiveContains("requires")
            && nsError.localizedDescription.localizedCaseInsensitiveContains("index")
    }

    var isPetankoRequiresRecentLoginError: Bool {
        let nsError = self as NSError
        return nsError.domain == AuthErrorDomain
            && nsError.code == AuthErrorCode.requiresRecentLogin.rawValue
    }

    var isPetankoInvalidPasswordAuthError: Bool {
        let nsError = self as NSError
        guard nsError.domain == AuthErrorDomain else { return false }
        return nsError.code == AuthErrorCode.wrongPassword.rawValue
            || nsError.code == AuthErrorCode.invalidCredential.rawValue
            || nsError.code == AuthErrorCode.userMismatch.rawValue
    }
}

extension String {
    var petankoFallbackDisplayName: String {
        let name = split(separator: "@").first.map(String.init) ?? ""
        return name.trimmedForPetanko.isEmpty ? "petanko user" : name
    }
}
