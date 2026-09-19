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

    var petankoAuthErrorMessage: String? {
        let nsError = self as NSError
        guard nsError.domain == AuthErrorDomain,
              let code = AuthErrorCode(rawValue: nsError.code) else {
            return nil
        }

        switch code {
        case .invalidCredential, .wrongPassword, .userNotFound:
            return "メールアドレスまたはパスワードが違います。入力内容を確認してください。"
        case .invalidEmail:
            return "メールアドレスの形式を確認してください。"
        case .emailAlreadyInUse:
            return "このメールアドレスはすでに使われています。ログインをお試しください。"
        case .weakPassword:
            return "パスワードは6文字以上で設定してください。"
        case .tooManyRequests:
            return "何度も失敗したため、一時的に操作できません。少し時間をおいてからもう一度お試しください。"
        case .networkError:
            return "通信できませんでした。ネットワーク接続を確認してください。"
        case .userDisabled:
            return "このアカウントは現在利用できません。"
        case .operationNotAllowed:
            return "メールアドレスでのログインが利用できません。設定を確認してください。"
        case .requiresRecentLogin:
            return "安全のため、もう一度ログイン確認が必要です。"
        default:
            return nil
        }
    }
}

extension String {
    var petankoFallbackDisplayName: String {
        let name = split(separator: "@").first.map(String.init) ?? ""
        return name.trimmedForPetanko.isEmpty ? "petanko user" : name
    }
}
