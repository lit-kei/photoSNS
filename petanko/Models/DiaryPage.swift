import FirebaseFirestore
import Foundation

struct DiaryPage: Identifiable, Hashable {
    let id: String
    var groupId: String
    var dateKey: String
    var title: String
    var background: ScrapbookBackground
    var backgroundImageURL: String?
    var textItems: [DiaryTextItem]
    var stampItems: [DiaryStampItem]
    var designItems: [DiaryDesignItem]
    var stickerLayout: [StickerLayout]
    var updatedAt: Date

    init(
        id: String,
        groupId: String,
        dateKey: String,
        title: String,
        background: ScrapbookBackground = .notebook,
        backgroundImageURL: String? = nil,
        textItems: [DiaryTextItem] = [],
        stampItems: [DiaryStampItem] = [],
        designItems: [DiaryDesignItem] = [],
        stickerLayout: [StickerLayout] = [],
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.groupId = groupId
        self.dateKey = dateKey
        self.title = title
        self.background = background
        self.backgroundImageURL = backgroundImageURL
        self.textItems = textItems
        self.stampItems = stampItems
        self.designItems = designItems
        self.stickerLayout = stickerLayout
        self.updatedAt = updatedAt
    }

    init(id: String, data: [String: Any]) {
        self.id = id
        self.groupId = data["groupId"] as? String ?? ""
        self.dateKey = data["dateKey"] as? String ?? Date().petankoDateKey
        self.title = data["title"] as? String ?? Date().petankoShortTitle
        self.background = ScrapbookBackground(rawValue: data["background"] as? String ?? "") ?? .notebook
        let storedBackgroundImageURL = data["backgroundImageURL"] as? String
        self.backgroundImageURL = storedBackgroundImageURL?.isEmpty == false ? storedBackgroundImageURL : nil
        self.textItems = (data["textItems"] as? [[String: Any]] ?? []).map(DiaryTextItem.init)
        self.stampItems = (data["stampItems"] as? [[String: Any]] ?? []).map(DiaryStampItem.init)
        self.designItems = (data["designItems"] as? [[String: Any]] ?? []).map(DiaryDesignItem.init)
        self.stickerLayout = (data["stickerLayout"] as? [[String: Any]] ?? []).map(StickerLayout.init)
        self.updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
    }

    var dictionary: [String: Any] {
        [
            "groupId": groupId,
            "dateKey": dateKey,
            "title": title,
            "background": background.rawValue,
            "backgroundImageURL": backgroundImageURL ?? "",
            "textItems": textItems.map(\.dictionary),
            "stampItems": stampItems.map(\.dictionary),
            "designItems": designItems.map(\.dictionary),
            "stickerLayout": stickerLayout.map(\.dictionary),
            "updatedAt": FieldValue.serverTimestamp()
        ]
    }
}

enum DiaryDesignEffect: String, PetankoOption {
    case invert
    case tint
    case translucent
    case eightBit

    var id: String { rawValue }

    var title: String {
        switch self {
        case .invert: "部分反転"
        case .tint: "グレーフィルター"
        case .translucent: "半透明カラー"
        case .eightBit: "8ビット"
        }
    }

    var systemImage: String {
        switch self {
        case .invert: "circle.lefthalf.filled.inverse"
        case .tint: "circle.lefthalf.filled"
        case .translucent: "rectangle.fill"
        case .eightBit: "square.grid.3x3.fill"
        }
    }
}

enum DiaryDesignShape: String, PetankoOption {
    case rectangle
    case circle
    case star
    case heart

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rectangle: "四角"
        case .circle: "丸"
        case .star: "星"
        case .heart: "ハート"
        }
    }

    var systemImage: String {
        switch self {
        case .rectangle: "square"
        case .circle: "circle"
        case .star: "star"
        case .heart: "heart"
        }
    }
}

struct DiaryDesignItem: Identifiable, Hashable {
    static let defaultColorHex = "#E11D48"
    static let defaultBorderColorHex = "#FFFFFF"
    static let legacyZIndex = -500_000

    let id: String
    var effect: DiaryDesignEffect
    var colorHex: String
    var opacity: Double
    var hasBorder: Bool
    var borderColorHex: String
    var shape: DiaryDesignShape
    var x: Double
    var y: Double
    var width: Double
    var height: Double
    var rotation: Double
    var scale: Double
    var zIndex: Int

    init(
        id: String = UUID().uuidString,
        effect: DiaryDesignEffect,
        colorHex: String = DiaryDesignItem.defaultColorHex,
        opacity: Double = 0.48,
        hasBorder: Bool = false,
        borderColorHex: String = DiaryDesignItem.defaultBorderColorHex,
        shape: DiaryDesignShape = .rectangle,
        x: Double = 180,
        y: Double = 240,
        width: Double = 170,
        height: Double = 92,
        rotation: Double = 0,
        scale: Double = 1,
        zIndex: Int = 0
    ) {
        self.id = id
        self.effect = effect
        self.colorHex = colorHex
        self.opacity = opacity
        self.hasBorder = hasBorder
        self.borderColorHex = borderColorHex
        self.shape = shape
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.rotation = rotation
        self.scale = scale
        self.zIndex = zIndex
    }

    init(_ data: [String: Any]) {
        self.id = data["id"] as? String ?? UUID().uuidString
        self.effect = DiaryDesignEffect(rawValue: data["effect"] as? String ?? "") ?? .translucent
        self.colorHex = data["colorHex"] as? String ?? DiaryDesignItem.defaultColorHex
        self.opacity = data["opacity"] as? Double ?? 0.48
        self.hasBorder = data["hasBorder"] as? Bool ?? false
        self.borderColorHex = data["borderColorHex"] as? String ?? DiaryDesignItem.defaultBorderColorHex
        self.shape = DiaryDesignShape(rawValue: data["shape"] as? String ?? "") ?? .rectangle
        self.x = data["x"] as? Double ?? 180
        self.y = data["y"] as? Double ?? 240
        self.width = data["width"] as? Double ?? 170
        self.height = data["height"] as? Double ?? 92
        self.rotation = data["rotation"] as? Double ?? 0
        self.scale = data["scale"] as? Double ?? 1
        self.zIndex = data["zIndex"] as? Int ?? DiaryDesignItem.legacyZIndex
    }

    var dictionary: [String: Any] {
        [
            "id": id,
            "effect": effect.rawValue,
            "colorHex": colorHex,
            "opacity": opacity,
            "hasBorder": hasBorder,
            "borderColorHex": borderColorHex,
            "shape": shape.rawValue,
            "x": x,
            "y": y,
            "width": width,
            "height": height,
            "rotation": rotation,
            "scale": scale,
            "zIndex": zIndex
        ]
    }
}

struct DiaryTextItem: Identifiable, Hashable {
    static let defaultColorHex = "#1F1B18"
    static let legacyZIndex = -2_000_000

    let id: String
    var text: String
    var x: Double
    var y: Double
    var fontName: String
    var colorHex: String
    var scale: Double
    var rotation: Double
    var zIndex: Int

    init(
        id: String = UUID().uuidString,
        text: String,
        x: Double = 24,
        y: Double = 28,
        fontName: String = "",
        colorHex: String = DiaryTextItem.defaultColorHex,
        scale: Double = 1,
        rotation: Double = 0,
        zIndex: Int = 0
    ) {
        self.id = id
        self.text = text
        self.x = x
        self.y = y
        self.fontName = fontName
        self.colorHex = colorHex
        self.scale = scale
        self.rotation = rotation
        self.zIndex = zIndex
    }

    init(_ data: [String: Any]) {
        self.id = data["id"] as? String ?? UUID().uuidString
        self.text = data["text"] as? String ?? ""
        self.x = data["x"] as? Double ?? 24
        self.y = data["y"] as? Double ?? 28
        self.fontName = data["fontName"] as? String ?? ""
        self.colorHex = data["colorHex"] as? String ?? DiaryTextItem.defaultColorHex
        self.scale = data["scale"] as? Double ?? 1
        self.rotation = data["rotation"] as? Double ?? 0
        self.zIndex = data["zIndex"] as? Int ?? DiaryTextItem.legacyZIndex
    }

    var dictionary: [String: Any] {
        [
            "id": id,
            "text": text,
            "x": x,
            "y": y,
            "fontName": fontName,
            "colorHex": colorHex,
            "scale": scale,
            "rotation": rotation,
            "zIndex": zIndex
        ]
    }
}

enum DiaryStampDesign: String, PetankoOption {
    case normal
    case sparkle
    case layered
    case neon
    case shadow

    var id: String { rawValue }

    var title: String {
        switch self {
        case .normal: "ノーマル"
        case .sparkle: "キラキラ"
        case .layered: "レイヤード"
        case .neon: "ネオン"
        case .shadow: "シャドウ"
        }
    }

    var systemImage: String {
        switch self {
        case .normal: "circle"
        case .sparkle: "sparkles"
        case .layered: "square.3.layers.3d"
        case .neon: "bolt.fill"
        case .shadow: "circle.lefthalf.filled"
        }
    }
}

struct DiaryStampItem: Identifiable, Hashable {
    static let defaultColorHex = "#1F1B18"
    static let legacyZIndex = -1_000_000

    let id: String
    var symbol: String
    var colorHex: String
    var design: DiaryStampDesign
    var x: Double
    var y: Double
    var rotation: Double
    var scale: Double
    var zIndex: Int

    init(
        id: String = UUID().uuidString,
        symbol: String,
        colorHex: String = DiaryStampItem.defaultColorHex,
        design: DiaryStampDesign = .normal,
        x: Double = 40,
        y: Double = 80,
        rotation: Double = -8,
        scale: Double = 1,
        zIndex: Int = 0
    ) {
        self.id = id
        self.symbol = symbol
        self.colorHex = colorHex
        self.design = design
        self.x = x
        self.y = y
        self.rotation = rotation
        self.scale = scale
        self.zIndex = zIndex
    }

    init(_ data: [String: Any]) {
        self.id = data["id"] as? String ?? UUID().uuidString
        self.symbol = data["symbol"] as? String ?? "★"
        self.colorHex = data["colorHex"] as? String ?? DiaryStampItem.defaultColorHex
        self.design = DiaryStampDesign(rawValue: data["design"] as? String ?? "") ?? .normal
        self.x = data["x"] as? Double ?? 40
        self.y = data["y"] as? Double ?? 80
        self.rotation = data["rotation"] as? Double ?? -8
        self.scale = data["scale"] as? Double ?? 1
        self.zIndex = data["zIndex"] as? Int ?? DiaryStampItem.legacyZIndex
    }

    var dictionary: [String: Any] {
        [
            "id": id,
            "symbol": symbol,
            "colorHex": colorHex,
            "design": design.rawValue,
            "x": x,
            "y": y,
            "rotation": rotation,
            "scale": scale,
            "zIndex": zIndex
        ]
    }
}
