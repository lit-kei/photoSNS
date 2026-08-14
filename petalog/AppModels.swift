//
//  AppModels.swift
//  petalog
//
//  Created by Codex on 2026/08/14.
//

import SwiftUI

protocol PetalogOption: CaseIterable, Identifiable, Hashable {
    var title: String { get }
    var systemImage: String { get }
}

struct StudentUser: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let avatar: String
}

struct MemoryGroup: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let icon: String
    let members: [StudentUser]
    let diaryCount: Int
    let todayStickers: [ScrapbookSticker]

    var todayStickerCount: Int {
        todayStickers.count
    }
}

struct DiaryMemory: Identifiable {
    let id = UUID()
    let dateLabel: String
    let title: String
    let group: MemoryGroup
    let background: ScrapbookBackground
}

struct ScrapbookSticker: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let author: StudentUser
    let comment: String
    let shape: StickerShapeOption
    let decoration: StickerDecoration
    let tint: Color
    let symbolName: String
    let offset: CGSize
    let rotation: Double
    let scale: Double
}

enum StickerShapeOption: String, PetalogOption {
    case circle
    case square
    case heart
    case star
    case cloud
    case flower
    case freeform

    var id: String { rawValue }

    var title: String {
        switch self {
        case .circle: "丸"
        case .square: "四角"
        case .heart: "ハート"
        case .star: "星"
        case .cloud: "雲"
        case .flower: "花"
        case .freeform: "自由形"
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
        case .freeform: "lasso"
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
    static let text = Color(red: 0.13, green: 0.16, blue: 0.22)
    static let secondaryText = Color(red: 0.46, green: 0.50, blue: 0.58)
    static let border = Color(red: 0.86, green: 0.88, blue: 0.91)
    static let background = Color(red: 0.96, green: 0.98, blue: 0.98)
    static let craft = Color(red: 0.77, green: 0.62, blue: 0.42)
    static let sky = Color(red: 0.78, green: 0.91, blue: 1.0)
    static let pinkPaper = Color(red: 1.0, green: 0.89, blue: 0.92)
    static let night = LinearGradient(
        colors: [
            Color(red: 0.06, green: 0.09, blue: 0.18),
            Color(red: 0.16, green: 0.19, blue: 0.36)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let photoGradient = LinearGradient(
        colors: [
            Color(red: 0.11, green: 0.64, blue: 0.73),
            Color(red: 0.98, green: 0.59, blue: 0.49),
            Color(red: 0.99, green: 0.84, blue: 0.37)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let cameraGradient = LinearGradient(
        colors: [
            Color(red: 0.08, green: 0.13, blue: 0.17),
            Color(red: 0.27, green: 0.43, blue: 0.48)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
}

enum SampleData {
    static let users = [
        StudentUser(name: "かい", avatar: "😆"),
        StudentUser(name: "けい", avatar: "😎"),
        StudentUser(name: "みお", avatar: "😊"),
        StudentUser(name: "りん", avatar: "🤩")
    ]

    static let beachStickers = [
        ScrapbookSticker(
            title: "海",
            author: users[0],
            comment: "海きれいだった！",
            shape: .circle,
            decoration: .sparkle,
            tint: .teal,
            symbolName: "water.waves",
            offset: CGSize(width: -82, height: -118),
            rotation: -9,
            scale: 1.0
        ),
        ScrapbookSticker(
            title: "お昼",
            author: users[1],
            comment: "今日のお昼",
            shape: .heart,
            decoration: .whiteOutline,
            tint: .orange,
            symbolName: "fork.knife",
            offset: CGSize(width: 72, height: -92),
            rotation: 12,
            scale: 0.92
        ),
        ScrapbookSticker(
            title: "看板",
            author: users[2],
            comment: "集合場所",
            shape: .star,
            decoration: .colorfulOutline,
            tint: .yellow,
            symbolName: "signpost.right.fill",
            offset: CGSize(width: -38, height: 70),
            rotation: -4,
            scale: 1.05
        ),
        ScrapbookSticker(
            title: "アイス",
            author: users[3],
            comment: "暑かった",
            shape: .cloud,
            decoration: .shadow,
            tint: .mint,
            symbolName: "snowflake",
            offset: CGSize(width: 92, height: 94),
            rotation: 7,
            scale: 0.88
        )
    ]

    static let profileStickers = [
        ScrapbookSticker(
            title: "花火",
            author: users[0],
            comment: "夏",
            shape: .flower,
            decoration: .sparkle,
            tint: .purple,
            symbolName: "sparkler",
            offset: .zero,
            rotation: -8,
            scale: 1.0
        ),
        ScrapbookSticker(
            title: "カラオケ",
            author: users[0],
            comment: "最高",
            shape: .star,
            decoration: .handDrawn,
            tint: .pink,
            symbolName: "music.mic",
            offset: .zero,
            rotation: 8,
            scale: 1.0
        ),
        ScrapbookSticker(
            title: "部活",
            author: users[0],
            comment: "練習後",
            shape: .freeform,
            decoration: .whiteOutline,
            tint: .green,
            symbolName: "figure.run",
            offset: .zero,
            rotation: -4,
            scale: 1.0
        )
    ]

    static let groups = [
        MemoryGroup(
            name: "海旅行メンバー",
            icon: "🏖",
            members: users,
            diaryCount: 7,
            todayStickers: beachStickers
        ),
        MemoryGroup(
            name: "放課後いつメン",
            icon: "🎒",
            members: Array(users.prefix(3)),
            diaryCount: 12,
            todayStickers: Array(beachStickers.prefix(3))
        ),
        MemoryGroup(
            name: "文化祭準備",
            icon: "🎪",
            members: Array(users.suffix(3)),
            diaryCount: 4,
            todayStickers: Array(beachStickers.suffix(3))
        )
    ]

    static let memories = [
        DiaryMemory(dateLabel: "8/14", title: "海", group: groups[0], background: .notebook),
        DiaryMemory(dateLabel: "8/10", title: "花火大会", group: groups[1], background: .stars),
        DiaryMemory(dateLabel: "7/28", title: "文化祭準備", group: groups[2], background: .craft),
        DiaryMemory(dateLabel: "7/20", title: "みんなでカラオケ", group: groups[1], background: .check)
    ]
}
