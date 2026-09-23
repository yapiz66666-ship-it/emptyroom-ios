import Foundation

/// Splits a jwxt room name such as "逸夫楼650材料制备实验室（二）", "逸B09材料加工成型" or
/// "博文楼(文综)北201" into a short code ("650", "B09", "北201"), a description and a floor.
struct RoomLabel: Hashable {
    let code: String
    let description: String
    let floor: Int?

    private static let labWords = ["实验", "机房", "分析", "工作室", "研究", "检测", "制备"]

    var isLab: Bool { RoomLabel.labWords.contains { description.contains($0) } }

    var floorTitle: String {
        guard let floor else { return "其他" }
        return floor < 0 ? "地下层" : "\(floor) 楼"
    }

    /// Sort key: floor, then code.
    var sortKey: (Int, String) { (floor ?? Int.max, code) }

    static func parse(building: String, room: String) -> RoomLabel {
        var rest = stripBuildingPrefix(building.trimmingCharacters(in: .whitespaces), room.trimmingCharacters(in: .whitespaces))
        // A leading zone in brackets, e.g. "(文综)北201" in 博文楼, becomes part of the description.
        var zone: String?
        if let match = firstMatch(#"^[(（]([^)）]{1,8})[)）]"#, in: rest) {
            zone = match[1].trimmingCharacters(in: .whitespaces)
            rest = String(rest.dropFirst(match[0].count)).trimmingCharacters(in: .whitespaces)
        }
        guard let regex = try? NSRegularExpression(pattern: #"[A-Za-z东南西北中]?\d{2,4}[A-Za-z]?"#),
              let match = regex.firstMatch(in: rest, range: NSRange(rest.startIndex..., in: rest)),
              let range = Range(match.range, in: rest)
        else {
            let code = String(rest.prefix(5))
            let tail = String(rest.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            return RoomLabel(code: code, description: joined(zone, tail), floor: nil)
        }
        let code = rest[range].uppercased()
        let trailing = (String(rest[..<range.lowerBound]) + String(rest[range.upperBound...]))
            .trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-_ "))
        return RoomLabel(code: code, description: joined(zone, trailing), floor: floor(of: code))
    }

    private static func joined(_ zone: String?, _ tail: String) -> String {
        [zone, tail.isEmpty ? nil : tail].compactMap { $0 }.joined(separator: " ")
    }

    private static func stripBuildingPrefix(_ building: String, _ room: String) -> String {
        var base = building
        if base.hasSuffix("教学楼") { base.removeLast(3) } else if base.hasSuffix("楼") { base.removeLast() }
        var prefixes = [building, base].filter { !$0.isEmpty }
        if base.count > 1 { prefixes += (1..<base.count).reversed().map { String(base.prefix($0)) } }
        guard let prefix = prefixes.first(where: { room.hasPrefix($0) && room.count > $0.count }) else { return room }
        return String(room.dropFirst(prefix.count))
    }

    private static func floor(of code: String) -> Int? {
        if code.hasPrefix("B") { return -1 }
        let digits = code.drop { !($0.isASCII && $0.isNumber) }.prefix { $0.isASCII && $0.isNumber }
        switch digits.count {
        case 3: return Int(String(digits.prefix(1)))
        case 4: return Int(String(digits.prefix(2)))
        default: return nil
        }
    }
}
