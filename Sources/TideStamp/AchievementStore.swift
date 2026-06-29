import Foundation

final class AchievementStore: ObservableObject {
    // Shape: ["2026-06-28": ["item-uuid": completionCount]]
    @Published private(set) var completionsByDay: [String: [String: Int]] {
        didSet {
            save()
        }
    }

    private let storageKey = "achievementCompletionsByDay"
    private let userDefaults: UserDefaults
    private let calendar: Calendar

    init(userDefaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.userDefaults = userDefaults
        self.calendar = calendar

        if let data = userDefaults.data(forKey: storageKey),
           let completions = try? JSONDecoder().decode([String: [String: Int]].self, from: data) {
            self.completionsByDay = completions
        } else {
            self.completionsByDay = [:]
        }
    }

    func recordCompletion(for item: ReminderItem, on date: Date = Date()) {
        let dayKey = Self.dayKey(for: date, calendar: calendar)
        let itemKey = item.id.uuidString
        completionsByDay[dayKey, default: [:]][itemKey, default: 0] += 1
    }

    func completionCount(for item: ReminderItem, on date: Date) -> Int {
        let dayKey = Self.dayKey(for: date, calendar: calendar)
        return completionsByDay[dayKey]?[item.id.uuidString] ?? 0
    }

    func hasCompletions(on date: Date) -> Bool {
        let dayKey = Self.dayKey(for: date, calendar: calendar)
        return completionsByDay[dayKey]?.values.contains { $0 > 0 } ?? false
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(completionsByDay) else {
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
