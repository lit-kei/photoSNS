import Foundation

protocol PetankoOption: CaseIterable, Identifiable, Hashable {
    var title: String { get }
    var systemImage: String { get }
}

enum StickerCreationMode: String, CaseIterable, Identifiable, Hashable {
    case crop
    case backgroundRemoval

    var id: String { rawValue }
}

enum StickerEffect: String, PetankoOption {
    case original
    case grayscale
    case noir
    case sepia
    case vivid

    var id: String { rawValue }

    var title: String {
        switch self {
        case .original: "オリジナル"
        case .grayscale: "グレースケール"
        case .noir: "ノワール"
        case .sepia: "セピア"
        case .vivid: "ビビッド"
        }
    }

    var systemImage: String {
        switch self {
        case .original: "photo"
        case .grayscale: "circle.lefthalf.filled"
        case .noir: "circle.inset.filled"
        case .sepia: "camera.filters"
        case .vivid: "sun.max.fill"
        }
    }
}

enum StickerShapeOption: String, PetankoOption {
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

enum StickerDecoration: String, PetankoOption {
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
        case .colorfulOutline: "カラフルふち"
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

    var supportsCustomOutlineColor: Bool {
        switch self {
        case .sparkle, .colorfulOutline:
            true
        case .whiteOutline, .shadow, .handDrawn, .none:
            false
        }
    }
}

enum ScrapbookBackground: String, PetankoOption {
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
        case .pink: "黄色"
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
