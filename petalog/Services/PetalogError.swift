import FirebaseFirestore
import Foundation

enum PetalogError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case .message(let message): message
        }
    }
}

extension Error {
    var isPetalogOfflineFirestoreError: Bool {
        let nsError = self as NSError
        return nsError.code == FirestoreErrorCode.unavailable.rawValue
            || nsError.localizedDescription.localizedCaseInsensitiveContains("client is offline")
    }
}

extension String {
    var petalogFallbackDisplayName: String {
        let name = split(separator: "@").first.map(String.init) ?? ""
        return name.trimmedForPetalog.isEmpty ? "petalog user" : name
    }
}
