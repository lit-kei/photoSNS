import FirebaseFirestore
import Foundation

struct PetankoGroup: Identifiable, Hashable {
    let id: String
    var name: String
    var icon: String
    var iconURL: String?
    var inviteCode: String
    var ownerId: String
    var memberIds: [String]
    var memberNames: [String]
    var memberAvatars: [String]
    var diaryCount: Int
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        name: String,
        icon: String = "📘",
        iconURL: String? = nil,
        inviteCode: String,
        ownerId: String,
        memberIds: [String],
        memberNames: [String],
        memberAvatars: [String],
        diaryCount: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.iconURL = iconURL
        self.inviteCode = inviteCode
        self.ownerId = ownerId
        self.memberIds = memberIds
        self.memberNames = memberNames
        self.memberAvatars = memberAvatars
        self.diaryCount = diaryCount
        self.createdAt = createdAt
    }

    init(id: String, data: [String: Any]) {
        self.id = id
        self.name = data["name"] as? String ?? "グループ"
        self.icon = data["icon"] as? String ?? "📘"
        self.iconURL = data["iconURL"] as? String
        self.inviteCode = data["inviteCode"] as? String ?? ""
        self.ownerId = data["ownerId"] as? String ?? ""
        self.memberIds = data["memberIds"] as? [String] ?? []
        self.memberNames = data["memberNames"] as? [String] ?? []
        self.memberAvatars = data["memberAvatars"] as? [String] ?? []
        self.diaryCount = data["diaryCount"] as? Int ?? 0
        self.createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
    }

    var dictionary: [String: Any] {
        [
            "name": name,
            "icon": icon,
            "iconURL": iconURL as Any,
            "inviteCode": inviteCode,
            "ownerId": ownerId,
            "memberIds": memberIds,
            "memberNames": memberNames,
            "memberAvatars": memberAvatars,
            "diaryCount": diaryCount,
            "createdAt": Timestamp(date: createdAt)
        ]
    }
}
