import FirebaseFirestore
import Foundation

struct AppUser: Identifiable, Hashable {
    let id: String
    var email: String
    var playerId: String
    var displayName: String
    var avatar: String
    var avatarURL: String?
    var createdAt: Date
    var updatedAt: Date
    var termsAcceptedAt: Date?

    init(
        id: String,
        email: String = "",
        playerId: String? = nil,
        displayName: String,
        avatar: String = "",
        avatarURL: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        termsAcceptedAt: Date? = nil
    ) {
        self.id = id
        self.email = email
        self.playerId = playerId ?? Self.makePlayerId(from: id)
        self.displayName = displayName
        self.avatar = avatar
        self.avatarURL = avatarURL
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.termsAcceptedAt = termsAcceptedAt
    }

    init(id: String, data: [String: Any]) {
        self.id = id
        self.email = data["email"] as? String ?? ""
        self.playerId = data["playerId"] as? String ?? Self.makePlayerId(from: id)
        self.displayName = data["displayName"] as? String ?? "petalog user"
        self.avatar = data["avatar"] as? String ?? ""
        self.avatarURL = data["avatarURL"] as? String
        self.createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        self.updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
        self.termsAcceptedAt = (data["termsAcceptedAt"] as? Timestamp)?.dateValue()
    }

    var dictionary: [String: Any] {
        var data: [String: Any] = [
            "email": email,
            "normalizedEmail": email.lowercased(),
            "playerId": playerId,
            "displayName": displayName,
            "avatar": avatar,
            "avatarURL": avatarURL as Any,
            "createdAt": Timestamp(date: createdAt),
            "updatedAt": FieldValue.serverTimestamp()
        ]
        if let termsAcceptedAt {
            data["termsAcceptedAt"] = Timestamp(date: termsAcceptedAt)
        }
        return data
    }

    /// Value stored in `groups.memberAvatars`. Profile photos take priority;
    /// emoji avatars and a stable system-image marker remain as fallbacks.
    var memberAvatarValue: String {
        if let avatarURL, !avatarURL.isEmpty {
            return avatarURL
        }
        return avatar.isEmpty ? "system:person.fill" : avatar
    }

    static func makePlayerId(from userId: String) -> String {
        let compactId = userId
            .uppercased()
            .filter { $0.isLetter || $0.isNumber }
        return "P" + String(compactId.prefix(8))
    }
}

struct AuthenticatedAccount: Hashable {
    let uid: String
    let email: String
}
