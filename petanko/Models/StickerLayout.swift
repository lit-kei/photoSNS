import Foundation

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
