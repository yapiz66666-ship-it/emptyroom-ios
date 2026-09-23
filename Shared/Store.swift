import Foundation

struct QueryOption: Codable, Hashable, Identifiable {
    let value: String
    let label: String
    var id: String { value }
}

struct TermSchedule {
    let buildingName: String
    let payload: TermPayload
    let savedAt: Date
}

/// Local storage shared by the app and the widget through the App Group. When the group is not
/// available (e.g. a sideload that dropped it) the app still works on its own defaults, but the
/// widget cannot see the data; [isSharedWithWidget] tells the UI.
final class Store {
    static let appGroup = "group.com.csuft.emptyroom"
    static let shared = Store()

    let defaults: UserDefaults
    let isSharedWithWidget: Bool

    init() {
        let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Store.appGroup)
        if container != nil, let group = UserDefaults(suiteName: Store.appGroup) {
            defaults = group
            isSharedWithWidget = true
        } else {
            defaults = .standard
            isSharedWithWidget = false
        }
    }

    private enum Key {
        static let termBuilding = "term_building"
        static let termPayload = "term_payload"
        static let termSavedAt = "term_saved_at"
        static let lastCampus = "last_campus"
        static let lastBuilding = "last_building"
    }

    // MARK: Term schedule

    func saveTerm(buildingName: String, payload: TermPayload, savedAt: Date = Date()) {
        guard let data = try? JSONEncoder().encode(payload) else { return }
        defaults.set(buildingName, forKey: Key.termBuilding)
        defaults.set(data, forKey: Key.termPayload)
        defaults.set(savedAt.timeIntervalSince1970, forKey: Key.termSavedAt)
    }

    func termSchedule() -> TermSchedule? {
        guard let building = defaults.string(forKey: Key.termBuilding),
              let data = defaults.data(forKey: Key.termPayload),
              let payload = try? JSONDecoder().decode(TermPayload.self, from: data)
        else { return nil }
        return TermSchedule(
            buildingName: building,
            payload: payload,
            savedAt: Date(timeIntervalSince1970: defaults.double(forKey: Key.termSavedAt))
        )
    }

    /// Free rooms on [date], computed offline from the stored term schedule.
    func result(for date: Date) -> DayResult? {
        guard let schedule = termSchedule() else { return nil }
        return ScheduleParser.day(schedule.payload, buildingName: schedule.buildingName, date: date, queriedAt: schedule.savedAt)
    }

    func clearTerm() {
        [Key.termBuilding, Key.termPayload, Key.termSavedAt].forEach(defaults.removeObject(forKey:))
    }

    // MARK: Last selection (one-tap re-query)

    func saveSelection(campus: QueryOption, building: QueryOption) {
        defaults.set(try? JSONEncoder().encode(campus), forKey: Key.lastCampus)
        defaults.set(try? JSONEncoder().encode(building), forKey: Key.lastBuilding)
    }

    var lastCampus: QueryOption? { option(Key.lastCampus) }
    var lastBuilding: QueryOption? { option(Key.lastBuilding) }

    private func option(_ key: String) -> QueryOption? {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(QueryOption.self, from: $0) }
    }
}
