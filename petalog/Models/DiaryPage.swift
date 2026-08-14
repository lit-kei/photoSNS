import FirebaseFirestore
import Foundation

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
