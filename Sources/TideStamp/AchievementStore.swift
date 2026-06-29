import Foundation

struct AchievementProgress: Codable {
    var released: Int
    var completed: Int
}

final class AchievementStore: ObservableObject {
    // Shape: ["2026-06-28": ["item-uuid": { released, completed }]]
    @Published private(set) var progressByDay: [String: [String: AchievementProgress]] {
        didSet {
            save()
        }
    }

    private let storageKey = "achievementProgressByDay"
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
    }

    func recordRelease(for item: ReminderItem, on date: Date = Date()) {
        updateProgress(for: item, on: date) { progress in
            progress.released += 1
        }
    }

    func recordCompletion(for item: ReminderItem, on date: Date = Date()) {
        updateProgress(for: item, on: date) { progress in
            progress.completed += 1
        }
    }

    func progress(for item: ReminderItem, on date: Date) -> AchievementProgress {
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

    private func save() {
        guard let data = try? JSONEncoder().encode(progressByDay) else {
            return
        }

        userDefaults.set(data, forKey: storageKey)
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
