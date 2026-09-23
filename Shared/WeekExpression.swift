import Foundation

/// Whether a week expression such as "1-4,10-13周" or "2-16周(双)" covers a teaching week.
enum WeekExpression {
    private static let normal = try! NSRegularExpression(
        pattern: #"(\d+(?:-\d+)?(?:,\d+(?:-\d+)?)*)周(?:\(?([单双])\)?)?"#
    )
    private static let parityBeforeWeek = try! NSRegularExpression(
        pattern: #"(\d+(?:-\d+)?(?:,\d+(?:-\d+)?)*)\(?([单双])\)?周"#
    )

    static func isActive(_ text: String, week: Int) -> Bool {
        let normalized = text
            .replacingOccurrences(of: "，", with: ",")
            .replacingOccurrences(of: "、", with: ",")
            .replacingOccurrences(of: "－", with: "-")
            .replacingOccurrences(of: "—", with: "-")
            .replacingOccurrences(of: "~", with: "-")
            .replacingOccurrences(of: "至", with: "-")
            .replacingOccurrences(of: " ", with: "")
        let ns = normalized as NSString
        let range = NSRange(location: 0, length: ns.length)
        let matches = normal.matches(in: normalized, range: range) + parityBeforeWeek.matches(in: normalized, range: range)
        if matches.isEmpty { return !text.trimmingCharacters(in: .whitespaces).isEmpty }
        return matches.contains { match in
            let clause = ns.substring(with: match.range(at: 1))
            let parityRange = match.range(at: 2)
            let parity = parityRange.location == NSNotFound ? "" : ns.substring(with: parityRange)
            return includes(clause, week: week) && matchesParity(parity, week: week)
        }
    }

    private static func includes(_ clause: String, week: Int) -> Bool {
        clause.split(separator: ",").contains { part in
            let bounds = part.split(separator: "-", maxSplits: 1).compactMap { Int($0) }
            switch bounds.count {
            case 1: return week == bounds[0]
            case 2: return (bounds[0]...max(bounds[0], bounds[1])).contains(week)
            default: return false
            }
        }
    }

    private static func matchesParity(_ parity: String, week: Int) -> Bool {
        switch parity {
        case "单": return week % 2 == 1
        case "双": return week % 2 == 0
        default: return true
        }
    }
}
