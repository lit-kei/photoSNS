import FirebaseFirestore
import Foundation

struct AppFriend: Identifiable, Hashable {
    let id: String
    var userId: String
    var friendId: String
    var friendName: String
    var friendEmail: String
    var friendAvatar: String
    var friendAvatarURL: String?
    var createdAt: Date

    init(
        id: String,
        userId: String,
        friendId: String,
        friendName: String,
        friendEmail: String,
        friendAvatar: String = "",
        friendAvatarURL: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.friendId = friendId
        self.friendName = friendName
        self.friendEmail = friendEmail
        self.friendAvatar = friendAvatar
        self.friendAvatarURL = friendAvatarURL
        self.createdAt = createdAt
    }

    init(id: String, data: [String: Any]) {
        self.id = id
        self.userId = data["userId"] as? String ?? ""
        self.friendId = data["friendId"] as? String ?? ""
        self.friendName = data["friendName"] as? String ?? "petalog user"
        self.friendEmail = data["friendEmail"] as? String ?? ""
        self.friendAvatar = data["friendAvatar"] as? String ?? ""
        self.friendAvatarURL = data["friendAvatarURL"] as? String
        self.createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
    }

    var dictionary: [String: Any] {
        [
            "userId": userId,
            "friendId": friendId,
            "friendName": friendName,
            "friendEmail": friendEmail,
            "friendAvatar": friendAvatar,
            "friendAvatarURL": friendAvatarURL as Any,
            "createdAt": Timestamp(date: createdAt)
        ]
    }
}
