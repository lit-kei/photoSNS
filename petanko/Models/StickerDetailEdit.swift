import Foundation

enum StickerDetailShapeKind: String, PetankoOption {
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

enum StickerDetailFilterKind: String, PetankoOption {
    case invert
    case grayscale
    case translucentColor
    case pixelate
    case sepia
    case vivid

    var id: String { rawValue }

    var title: String {
        switch self {
        case .invert: "部分反転"
        case .grayscale: "グレー"
        case .translucentColor: "半透明カラー"
        case .pixelate: "8ビット"
        case .sepia: "セピア"
        case .vivid: "ビビッド"
        }
    }

    var systemImage: String {
        switch self {
        case .invert: "circle.lefthalf.filled.inverse"
        case .grayscale: "circle.lefthalf.filled"
        case .translucentColor: "rectangle.fill"
        case .pixelate: "square.grid.3x3.fill"
        case .sepia: "camera.filters"
        case .vivid: "sun.max.fill"
        }
    }
}

enum StickerDetailFillPatternKind: String, PetankoOption {
    case solid
    case polkaDot
    case checker
    case stripe
    case diagonalStripe
    case grid
    case flower

    var id: String { rawValue }

    var title: String {
        switch self {
        case .solid: "単色"
        case .polkaDot: "水玉"
        case .checker: "チェック"
        case .stripe: "ストライプ"
        case .diagonalStripe: "ななめ"
        case .grid: "格子"
        case .flower: "小花"
        }
    }

    var systemImage: String {
        switch self {
        case .solid: "square.fill"
        case .polkaDot: "circle.grid.2x2.fill"
        case .checker: "checkerboard.rectangle"
        case .stripe: "line.3.horizontal"
        case .diagonalStripe: "line.diagonal"
        case .grid: "grid"
        case .flower: "camera.macro"
        }
    }
}

enum StickerDetailElementID: Hashable, Identifiable {
    case shape(String)
    case filter(String)

    var id: String {
        switch self {
        case .shape(let id): "shape:\(id)"
        case .filter(let id): "filter:\(id)"
        }
    }
}

struct StickerDetailShapeItem: Identifiable, Hashable {
    static let transparentColorHex = "transparent"

    let id: String
    var type: StickerDetailShapeKind
    var x: Double
    var y: Double
    var width: Double
    var height: Double
    var scale: Double
    var rotation: Double
    var fillColorHex: String
    var fillPattern: StickerDetailFillPatternKind
    var fillPatternDetail: Double
    var strokeColorHex: String
    var strokeWidth: Double
    var isFilterEnabled: Bool
    var zIndex: Int

    init(
        id: String = UUID().uuidString,
        type: StickerDetailShapeKind,
        x: Double = 256,
        y: Double = 256,
        width: Double = 150,
        height: Double = 150,
        scale: Double = 1,
        rotation: Double = 0,
        fillColorHex: String = "#F7B267",
        fillPattern: StickerDetailFillPatternKind = .solid,
        fillPatternDetail: Double = 0.5,
        strokeColorHex: String = "#FFFFFF",
        strokeWidth: Double = 6,
        isFilterEnabled: Bool = true,
        zIndex: Int
    ) {
        self.id = id
        self.type = type
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.scale = scale
        self.rotation = rotation
        self.fillColorHex = fillColorHex
        self.fillPattern = fillPattern
        self.fillPatternDetail = fillPatternDetail
        self.strokeColorHex = strokeColorHex
        self.strokeWidth = strokeWidth
        self.isFilterEnabled = isFilterEnabled
        self.zIndex = zIndex
    }
}

struct StickerDetailFilterItem: Identifiable, Hashable {
    let id: String
    var type: StickerDetailFilterKind
    var maskShape: StickerDetailShapeKind
    var x: Double
    var y: Double
    var width: Double
    var height: Double
    var scale: Double
    var rotation: Double
    var colorHex: String
    var opacity: Double
    var pixelScale: Double
    var zIndex: Int

    init(
        id: String = UUID().uuidString,
        type: StickerDetailFilterKind,
        maskShape: StickerDetailShapeKind = .rectangle,
        x: Double = 256,
        y: Double = 256,
        width: Double = 180,
        height: Double = 130,
        scale: Double = 1,
        rotation: Double = 0,
        colorHex: String = "#E11D48",
        opacity: Double = 0.45,
        pixelScale: Double = 12,
        zIndex: Int
    ) {
        self.id = id
        self.type = type
        self.maskShape = maskShape
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.scale = scale
        self.rotation = rotation
        self.colorHex = colorHex
        self.opacity = opacity
        self.pixelScale = pixelScale
        self.zIndex = zIndex
    }
}

struct StickerDetailEdit: Hashable {
    var shapes: [StickerDetailShapeItem] = []
    var filters: [StickerDetailFilterItem] = []
    var nextZIndex: Int = 0

    var isEmpty: Bool {
        shapes.isEmpty && filters.isEmpty
    }

    mutating func nextOrder() -> Int {
        nextZIndex += 1
        return nextZIndex
    }
}
