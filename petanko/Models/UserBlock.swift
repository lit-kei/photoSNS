import FirebaseFirestore
import Foundation

struct UserBlock: Identifiable, Hashable {
    let id: String
    var blockerId: String
    var blockedUserId: String
    var createdAt: Date

    init(id: String, blockerId: String, blockedUserId: String, createdAt: Date = Date()) {
        self.id = id
        self.blockerId = blockerId
        self.blockedUserId = blockedUserId
        self.createdAt = createdAt
    }

    init(id: String, data: [String: Any]) {
        self.id = id
        self.blockerId = data["blockerId"] as? String ?? ""
        self.blockedUserId = data["blockedUserId"] as? String ?? id
        self.createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
    }

    var dictionary: [String: Any] {
        [
            "blockerId": blockerId,
            "blockedUserId": blockedUserId,
            "createdAt": Timestamp(date: createdAt)
        ]
    }
}
