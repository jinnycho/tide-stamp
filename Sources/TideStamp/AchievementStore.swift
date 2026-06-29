import Foundation

struct AchievementProgress: Codable {
    var released: Int
    var completed: Int
}

struct TrackedReminderItem: Identifiable, Codable {
    var id: UUID
    var title: String
    var intervalMinutes: Int
    var firstActiveDay: String
    var deletedDay: String?
}

final class AchievementStore: ObservableObject {
    // Shape: ["2026-06-28": ["item-uuid": { released, completed }]]
    @Published private(set) var progressByDay: [String: [String: AchievementProgress]] {
        didSet {
            save()
        }
    }

    @Published private(set) var itemCatalog: [String: TrackedReminderItem] {
        didSet {
            saveItemCatalog()
        }
    }

    private let storageKey = "achievementProgressByDay"
    private let itemCatalogStorageKey = "trackedReminderItems"
    private let userDefaults: UserDefaults
    private let calendar: Calendar

    init(userDefaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.userDefaults = userDefaults
        self.calendar = calendar

        if let data = userDefaults.data(forKey: storageKey),
           let progress = try? JSONDecoder().decode([String: [String: AchievementProgress]].self, from: data) {
            self.progressByDay = progress
        } else {
            self.progressByDay = [:]
        }

        if let data = userDefaults.data(forKey: itemCatalogStorageKey),
           let itemCatalog = try? JSONDecoder().decode([String: TrackedReminderItem].self, from: data) {
            self.itemCatalog = itemCatalog
        } else {
            self.itemCatalog = [:]
        }
    }

    func recordRelease(for item: ReminderItem, on date: Date = Date()) {
        ensureTrackedItem(for: item, on: date)

        updateProgress(for: item, on: date) { progress in
            progress.released += 1
        }
    }

    func recordCompletion(for item: ReminderItem, on date: Date = Date()) {
        ensureTrackedItem(for: item, on: date)

        updateProgress(for: item, on: date) { progress in
            progress.completed += 1
        }
    }

    func syncDeletedItems(currentItems: [ReminderItem], on date: Date = Date()) {
        let dayKey = Self.dayKey(for: date, calendar: calendar)
        let activeIDs = Set(
            currentItems
                .filter { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .map { $0.id.uuidString }
        )

        for (itemKey, trackedItem) in itemCatalog where !activeIDs.contains(itemKey) && trackedItem.deletedDay == nil {
            var deletedItem = trackedItem
            deletedItem.deletedDay = dayKey
            itemCatalog[itemKey] = deletedItem
        }
    }

    func trackedItemsWithProgress(on date: Date) -> [TrackedReminderItem] {
        let dayKey = Self.dayKey(for: date, calendar: calendar)
        let itemIDsWithProgress = Set(
            progressByDay[dayKey, default: [:]]
                .filter { _, progress in
                    progress.released > 0 || progress.completed > 0
                }
                .map(\.key)
        )

        return itemCatalog.values
            .filter { item in
                itemIDsWithProgress.contains(item.id.uuidString)
            }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    func progress(for item: ReminderItem, on date: Date) -> AchievementProgress {
        let dayKey = Self.dayKey(for: date, calendar: calendar)
        return progressByDay[dayKey]?[item.id.uuidString] ?? AchievementProgress(released: 0, completed: 0)
    }

    func progress(for item: TrackedReminderItem, on date: Date) -> AchievementProgress {
        let dayKey = Self.dayKey(for: date, calendar: calendar)
        return progressByDay[dayKey]?[item.id.uuidString] ?? AchievementProgress(released: 0, completed: 0)
    }

    func hasCompletions(on date: Date) -> Bool {
        let dayKey = Self.dayKey(for: date, calendar: calendar)
        return progressByDay[dayKey]?.values.contains { $0.completed > 0 } ?? false
    }

    private func updateProgress(
        for item: ReminderItem,
        on date: Date,
        update: (inout AchievementProgress) -> Void
    ) {
        let dayKey = Self.dayKey(for: date, calendar: calendar)
        let itemKey = item.id.uuidString
        var progress = progressByDay[dayKey]?[itemKey] ?? AchievementProgress(released: 0, completed: 0)
        update(&progress)
        progressByDay[dayKey, default: [:]][itemKey] = progress
    }

    private func ensureTrackedItem(for item: ReminderItem, on date: Date) {
        let dayKey = Self.dayKey(for: date, calendar: calendar)
        let itemKey = item.id.uuidString
        let trimmedTitle = item.title.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedTitle.isEmpty else {
            return
        }

        if var trackedItem = itemCatalog[itemKey] {
            trackedItem.title = trimmedTitle
            trackedItem.intervalMinutes = item.intervalMinutes
            trackedItem.deletedDay = nil
            itemCatalog[itemKey] = trackedItem
        } else {
            itemCatalog[itemKey] = TrackedReminderItem(
                id: item.id,
                title: trimmedTitle,
                intervalMinutes: item.intervalMinutes,
                firstActiveDay: dayKey,
                deletedDay: nil
            )
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(progressByDay) else {
            return
        }

        userDefaults.set(data, forKey: storageKey)
    }

    private func saveItemCatalog() {
        guard let data = try? JSONEncoder().encode(itemCatalog) else {
            return
        }

        userDefaults.set(data, forKey: itemCatalogStorageKey)
    }

    private static func dayKey(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }
}
