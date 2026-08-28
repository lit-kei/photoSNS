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
        self.friendName = data["friendName"] as? String ?? "petanko user"
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
            "friendAvatar": friendAvatar,
            "friendAvatarURL": friendAvatarURL as Any,
            "createdAt": Timestamp(date: createdAt)
        ]
    }
}

struct FriendRequest: Identifiable, Hashable {
    let id: String
    var fromUserId: String
    var fromName: String
    var fromAvatar: String
    var fromAvatarURL: String?
    var toUserId: String
    var toName: String
    var toAvatar: String
    var toAvatarURL: String?
    var status: String
    var createdAt: Date

    init(
        id: String,
        fromUserId: String,
        fromName: String,
        fromAvatar: String = "",
        fromAvatarURL: String? = nil,
        toUserId: String,
        toName: String,
        toAvatar: String = "",
        toAvatarURL: String? = nil,
        status: String = "pending",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.fromUserId = fromUserId
        self.fromName = fromName
        self.fromAvatar = fromAvatar
        self.fromAvatarURL = fromAvatarURL
        self.toUserId = toUserId
        self.toName = toName
        self.toAvatar = toAvatar
        self.toAvatarURL = toAvatarURL
        self.status = status
        self.createdAt = createdAt
    }

    init(id: String, data: [String: Any]) {
        self.id = id
        self.fromUserId = data["fromUserId"] as? String ?? ""
        self.fromName = data["fromName"] as? String ?? "petanko user"
        self.fromAvatar = data["fromAvatar"] as? String ?? ""
        self.fromAvatarURL = data["fromAvatarURL"] as? String
        self.toUserId = data["toUserId"] as? String ?? ""
        self.toName = data["toName"] as? String ?? "petanko user"
        self.toAvatar = data["toAvatar"] as? String ?? ""
        self.toAvatarURL = data["toAvatarURL"] as? String
        self.status = data["status"] as? String ?? "pending"
        self.createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
    }

    var dictionary: [String: Any] {
        [
            "fromUserId": fromUserId,
            "fromName": fromName,
            "fromAvatar": fromAvatar,
            "fromAvatarURL": fromAvatarURL as Any,
            "toUserId": toUserId,
            "toName": toName,
            "toAvatar": toAvatar,
            "toAvatarURL": toAvatarURL as Any,
            "status": status,
            "createdAt": Timestamp(date: createdAt),
            "updatedAt": FieldValue.serverTimestamp()
        ]
    }
}
