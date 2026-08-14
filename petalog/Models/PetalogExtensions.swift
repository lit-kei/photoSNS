import Foundation

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
