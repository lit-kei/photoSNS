import FirebaseFirestore
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
}

extension String {
    var petankoFallbackDisplayName: String {
        let name = split(separator: "@").first.map(String.init) ?? ""
        return name.trimmedForPetanko.isEmpty ? "petanko user" : name
    }
}
