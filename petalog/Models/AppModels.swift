//
//  AppModels.swift
//  petalog
//

import CoreGraphics
import FirebaseFirestore
import Foundation
import SwiftUI

protocol PetalogOption: CaseIterable, Identifiable, Hashable {
    var title: String { get }
    var systemImage: String { get }
}

struct AppUser: Identifiable, Hashable {
    let id: String
    var displayName: String
    var avatar: String
    var avatarURL: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String,
        displayName: String,
        avatar: String = "🙂",
        avatarURL: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.displayName = displayName
        self.avatar = avatar
        self.avatarURL = avatarURL
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(id: String, data: [String: Any]) {
        self.id = id
        self.displayName = data["displayName"] as? String ?? "petalog user"
        self.avatar = data["avatar"] as? String ?? "🙂"
        self.avatarURL = data["avatarURL"] as? String
        self.createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        self.updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
    }

    var dictionary: [String: Any] {
        [
            "displayName": displayName,
            "avatar": avatar,
            "avatarURL": avatarURL as Any,
            "createdAt": Timestamp(date: createdAt),
            "updatedAt": FieldValue.serverTimestamp()
        ]
    }
}

struct PetalogGroup: Identifiable, Hashable {
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

struct DiaryPage: Identifiable, Hashable {
    let id: String
    var groupId: String
    var dateKey: String
    var title: String
    var background: ScrapbookBackground
    var textItems: [DiaryTextItem]
    var stampItems: [DiaryStampItem]
    var stickerLayout: [StickerLayout]
    var updatedAt: Date

    init(
        id: String,
        groupId: String,
        dateKey: String,
        title: String,
        background: ScrapbookBackground = .notebook,
        textItems: [DiaryTextItem] = [],
        stampItems: [DiaryStampItem] = [],
        stickerLayout: [StickerLayout] = [],
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.groupId = groupId
        self.dateKey = dateKey
        self.title = title
        self.background = background
        self.textItems = textItems
        self.stampItems = stampItems
        self.stickerLayout = stickerLayout
        self.updatedAt = updatedAt
    }

    init(id: String, data: [String: Any]) {
        self.id = id
        self.groupId = data["groupId"] as? String ?? ""
        self.dateKey = data["dateKey"] as? String ?? Date().petalogDateKey
        self.title = data["title"] as? String ?? Date().petalogShortTitle
        self.background = ScrapbookBackground(rawValue: data["background"] as? String ?? "") ?? .notebook
        self.textItems = (data["textItems"] as? [[String: Any]] ?? []).map(DiaryTextItem.init)
        self.stampItems = (data["stampItems"] as? [[String: Any]] ?? []).map(DiaryStampItem.init)
        self.stickerLayout = (data["stickerLayout"] as? [[String: Any]] ?? []).map(StickerLayout.init)
        self.updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
    }

    var dictionary: [String: Any] {
        [
            "groupId": groupId,
            "dateKey": dateKey,
            "title": title,
            "background": background.rawValue,
            "textItems": textItems.map(\.dictionary),
            "stampItems": stampItems.map(\.dictionary),
            "stickerLayout": stickerLayout.map(\.dictionary),
            "updatedAt": FieldValue.serverTimestamp()
        ]
    }
}

struct StickerPost: Identifiable, Hashable {
    let id: String
    var groupId: String
    var diaryId: String
    var dateKey: String
    var authorId: String
    var authorName: String
    var authorAvatar: String
    var comment: String
    var shape: StickerShapeOption
    var decoration: StickerDecoration
    var originalPhotoURL: String
    var stickerImageURL: String
    var layout: StickerLayout
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        groupId: String,
        diaryId: String,
        dateKey: String,
        authorId: String,
        authorName: String,
        authorAvatar: String,
        comment: String,
        shape: StickerShapeOption,
        decoration: StickerDecoration,
        originalPhotoURL: String = "",
        stickerImageURL: String = "",
        layout: StickerLayout,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.groupId = groupId
        self.diaryId = diaryId
        self.dateKey = dateKey
        self.authorId = authorId
        self.authorName = authorName
        self.authorAvatar = authorAvatar
        self.comment = comment
        self.shape = shape
        self.decoration = decoration
        self.originalPhotoURL = originalPhotoURL
        self.stickerImageURL = stickerImageURL
        self.layout = layout
        self.createdAt = createdAt
    }

    init(id: String, data: [String: Any]) {
        self.id = id
        self.groupId = data["groupId"] as? String ?? ""
        self.diaryId = data["diaryId"] as? String ?? ""
        self.dateKey = data["dateKey"] as? String ?? Date().petalogDateKey
        self.authorId = data["authorId"] as? String ?? ""
        self.authorName = data["authorName"] as? String ?? "friend"
        self.authorAvatar = data["authorAvatar"] as? String ?? "🙂"
        self.comment = data["comment"] as? String ?? ""
        self.shape = StickerShapeOption(rawValue: data["shape"] as? String ?? "") ?? .circle
        self.decoration = StickerDecoration(rawValue: data["decoration"] as? String ?? "") ?? .none
        self.originalPhotoURL = data["originalPhotoURL"] as? String ?? ""
        self.stickerImageURL = data["stickerImageURL"] as? String ?? ""
        self.layout = StickerLayout(data["layout"] as? [String: Any] ?? ["stickerId": id])
        self.createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
    }

    var dictionary: [String: Any] {
        [
            "groupId": groupId,
            "diaryId": diaryId,
            "dateKey": dateKey,
            "authorId": authorId,
            "authorName": authorName,
            "authorAvatar": authorAvatar,
            "comment": comment,
            "shape": shape.rawValue,
            "decoration": decoration.rawValue,
            "originalPhotoURL": originalPhotoURL,
            "stickerImageURL": stickerImageURL,
            "layout": layout.dictionary,
            "createdAt": Timestamp(date: createdAt)
        ]
    }
}

struct StickerLayout: Identifiable, Hashable {
    var id: String { stickerId }
    var stickerId: String
    var x: Double
    var y: Double
    var scale: Double
    var rotation: Double
    var zIndex: Int

    init(stickerId: String, x: Double = 0, y: Double = 0, scale: Double = 1, rotation: Double = 0, zIndex: Int = 0) {
        self.stickerId = stickerId
        self.x = x
        self.y = y
        self.scale = scale
        self.rotation = rotation
        self.zIndex = zIndex
    }

    init(_ data: [String: Any]) {
        self.stickerId = data["stickerId"] as? String ?? UUID().uuidString
        self.x = data["x"] as? Double ?? 0
        self.y = data["y"] as? Double ?? 0
        self.scale = data["scale"] as? Double ?? 1
        self.rotation = data["rotation"] as? Double ?? 0
        self.zIndex = data["zIndex"] as? Int ?? 0
    }

    var dictionary: [String: Any] {
        [
            "stickerId": stickerId,
            "x": x,
            "y": y,
            "scale": scale,
            "rotation": rotation,
            "zIndex": zIndex
        ]
    }
}

struct DiaryTextItem: Identifiable, Hashable {
    let id: String
    var text: String
    var x: Double
    var y: Double

    init(id: String = UUID().uuidString, text: String, x: Double = 24, y: Double = 28) {
        self.id = id
        self.text = text
        self.x = x
        self.y = y
    }

    init(_ data: [String: Any]) {
        self.id = data["id"] as? String ?? UUID().uuidString
        self.text = data["text"] as? String ?? ""
        self.x = data["x"] as? Double ?? 24
        self.y = data["y"] as? Double ?? 28
    }

    var dictionary: [String: Any] {
        ["id": id, "text": text, "x": x, "y": y]
    }
}

struct DiaryStampItem: Identifiable, Hashable {
    let id: String
    var symbol: String
    var x: Double
    var y: Double
    var rotation: Double

    init(id: String = UUID().uuidString, symbol: String, x: Double = 40, y: Double = 80, rotation: Double = -8) {
        self.id = id
        self.symbol = symbol
        self.x = x
        self.y = y
        self.rotation = rotation
    }

    init(_ data: [String: Any]) {
        self.id = data["id"] as? String ?? UUID().uuidString
        self.symbol = data["symbol"] as? String ?? "★"
        self.x = data["x"] as? Double ?? 40
        self.y = data["y"] as? Double ?? 80
        self.rotation = data["rotation"] as? Double ?? -8
    }

    var dictionary: [String: Any] {
        ["id": id, "symbol": symbol, "x": x, "y": y, "rotation": rotation]
    }
}

enum StickerShapeOption: String, PetalogOption {
    case circle
    case square
    case heart
    case star
    case cloud
    case flower

    var id: String { rawValue }

    var title: String {
        switch self {
        case .circle: "丸"
        case .square: "四角"
        case .heart: "ハート"
        case .star: "星"
        case .cloud: "雲"
        case .flower: "花"
        }
    }

    var systemImage: String {
        switch self {
        case .circle: "circle"
        case .square: "square"
        case .heart: "heart"
        case .star: "star"
        case .cloud: "cloud"
        case .flower: "camera.macro"
        }
    }
}

enum StickerDecoration: String, PetalogOption {
    case sparkle
    case whiteOutline
    case colorfulOutline
    case shadow
    case handDrawn
    case none

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sparkle: "キラキラ"
        case .whiteOutline: "白ふち"
        case .colorfulOutline: "色ふち"
        case .shadow: "影"
        case .handDrawn: "手描き"
        case .none: "なし"
        }
    }

    var systemImage: String {
        switch self {
        case .sparkle: "sparkles"
        case .whiteOutline: "circle.dashed"
        case .colorfulOutline: "paintpalette"
        case .shadow: "circle.lefthalf.filled"
        case .handDrawn: "scribble"
        case .none: "slash.circle"
        }
    }
}

enum ScrapbookBackground: String, PetalogOption {
    case notebook
    case grid
    case craft
    case sky
    case pink
    case stars
    case check

    var id: String { rawValue }

    var title: String {
        switch self {
        case .notebook: "ノート"
        case .grid: "方眼"
        case .craft: "クラフト"
        case .sky: "水色"
        case .pink: "ピンク"
        case .stars: "星空"
        case .check: "チェック"
        }
    }

    var systemImage: String {
        switch self {
        case .notebook: "doc.text"
        case .grid: "square.grid.3x3"
        case .craft: "shippingbox"
        case .sky: "cloud.sun"
        case .pink: "heart"
        case .stars: "moon.stars"
        case .check: "checkerboard.rectangle"
        }
    }
}

enum PetalogTheme {
    static let primary = Color(red: 0.12, green: 0.47, blue: 0.86)
    static let accent = Color(red: 0.96, green: 0.35, blue: 0.47)
    static let text = Color(red: 0.13, green: 0.16, blue: 0.22)
    static let secondaryText = Color(red: 0.46, green: 0.50, blue: 0.58)
    static let border = Color(red: 0.86, green: 0.88, blue: 0.91)
    static let background = Color(red: 0.96, green: 0.98, blue: 0.98)
    static let craft = Color(red: 0.77, green: 0.62, blue: 0.42)
    static let sky = Color(red: 0.78, green: 0.91, blue: 1.0)
    static let pinkPaper = Color(red: 1.0, green: 0.89, blue: 0.92)
}

extension Date {
    nonisolated var petalogDateKey: String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: self)
    }

    nonisolated var petalogDisplayDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日 EEEE"
        return formatter.string(from: self)
    }

    nonisolated var petalogShortTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M/d"
        return "\(formatter.string(from: self)) の絵日記"
    }
}

extension String {
    var trimmedForPetalog: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
