import FirebaseFirestore
import Foundation
import SwiftUI

struct StickerPost: Identifiable, Hashable {
    let id: String
    var assetId: String
    var groupId: String
    var diaryId: String
    var dateKey: String
    var authorId: String
    var authorName: String
    var authorAvatar: String
    var comment: String
    var shape: StickerShapeOption
    var decoration: StickerDecoration
    var stickerImageURL: String
    var layout: StickerLayout
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        assetId: String,
        groupId: String,
        diaryId: String,
        dateKey: String,
        authorId: String,
        authorName: String,
        authorAvatar: String,
        comment: String,
        shape: StickerShapeOption,
        decoration: StickerDecoration,
        stickerImageURL: String = "",
        layout: StickerLayout,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.assetId = assetId
        self.groupId = groupId
        self.diaryId = diaryId
        self.dateKey = dateKey
        self.authorId = authorId
        self.authorName = authorName
        self.authorAvatar = authorAvatar
        self.comment = comment
        self.shape = shape
        self.decoration = decoration
        self.stickerImageURL = stickerImageURL
        self.layout = layout
        self.createdAt = createdAt
    }

    init(id: String, data: [String: Any]) {
        self.id = id
        self.assetId = data["assetId"] as? String ?? ""
        self.groupId = data["groupId"] as? String ?? ""
        self.diaryId = data["diaryId"] as? String ?? ""
        self.dateKey = data["dateKey"] as? String ?? Date().petalogDateKey
        self.authorId = data["authorId"] as? String ?? ""
        self.authorName = data["authorName"] as? String ?? "friend"
        self.authorAvatar = data["authorAvatar"] as? String ?? ""
        self.comment = data["comment"] as? String ?? ""
        self.shape = StickerShapeOption(rawValue: data["shape"] as? String ?? "") ?? .circle
        self.decoration = StickerDecoration(rawValue: data["decoration"] as? String ?? "") ?? .none
        self.stickerImageURL = data["stickerImageURL"] as? String ?? ""
        self.layout = StickerLayout(data["layout"] as? [String: Any] ?? ["stickerId": id])
        self.createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
    }

    var dictionary: [String: Any] {
        [
            "assetId": assetId,
            "groupId": groupId,
            "diaryId": diaryId,
            "dateKey": dateKey,
            "authorId": authorId,
            "authorName": authorName,
            "authorAvatar": authorAvatar,
            "comment": comment,
            "shape": shape.rawValue,
            "decoration": decoration.rawValue,
            "stickerImageURL": stickerImageURL,
            "layout": layout.dictionary,
            "createdAt": Timestamp(date: createdAt)
        ]
    }
}

struct StickerDraft: Hashable {
    var shape: StickerShapeOption = .circle
    var decoration: StickerDecoration = .sparkle
    var cropScale: Double = 1
    var cropRotation: Double = 0
    var cropOffset: CGSize = .zero
    var comment: String = ""
}
