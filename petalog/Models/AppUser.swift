import FirebaseFirestore
import Foundation

struct AppUser: Identifiable, Hashable {
    let id: String
    var email: String
    var displayName: String
    var avatar: String
    var avatarURL: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String,
        email: String = "",
        displayName: String,
        avatar: String = "",
        avatarURL: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.avatar = avatar
        self.avatarURL = avatarURL
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(id: String, data: [String: Any]) {
        self.id = id
        self.email = data["email"] as? String ?? ""
        self.displayName = data["displayName"] as? String ?? "petalog user"
        self.avatar = data["avatar"] as? String ?? ""
        self.avatarURL = data["avatarURL"] as? String
        self.createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        self.updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
    }

    var dictionary: [String: Any] {
        [
            "email": email,
            "normalizedEmail": email.lowercased(),
            "displayName": displayName,
            "avatar": avatar,
            "avatarURL": avatarURL as Any,
            "createdAt": Timestamp(date: createdAt),
            "updatedAt": FieldValue.serverTimestamp()
        ]
    }

    /// Value stored in `groups.memberAvatars`. Profile photos take priority;
    /// emoji avatars and a stable system-image marker remain as fallbacks.
    var memberAvatarValue: String {
        if let avatarURL, !avatarURL.isEmpty {
            return avatarURL
        }
        return avatar.isEmpty ? "system:person.fill" : avatar
    }
}

struct AuthenticatedAccount: Hashable {
    let uid: String
    let email: String
}
