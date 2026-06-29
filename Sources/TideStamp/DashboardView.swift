import SwiftUI

struct DashboardView: View {
    @ObservedObject var settingsStore: ReminderSettingsStore
    @ObservedObject var achievementStore: AchievementStore

    @State private var displayedYear = Calendar.current.component(.year, from: Date())
    @State private var selectedDate = Date()

    private let calendar = Calendar.current
    private let dayColumns = Array(repeating: GridItem(.fixed(10), spacing: 4), count: 31)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button {
                    displayedYear -= 1
                    selectedDate = firstDayOfDisplayedYear
                } label: {
                    Image(systemName: "chevron.left")
                }

                Spacer()

                Text(String(displayedYear))
                    .font(.headline)

                Spacer()

                Button {
                    displayedYear += 1
                    selectedDate = firstDayOfDisplayedYear
                } label: {
                    Image(systemName: "chevron.right")
                }
            }

            ScrollView {
                LazyVGrid(columns: dayColumns, alignment: .leading, spacing: 4) {
                    ForEach(daysInDisplayedYear, id: \.self) { date in
                        Button {
                            selectedDate = date
                        } label: {
                            Circle()
                                .fill(dotColor(for: date))
                                .frame(width: 8, height: 8)
                        }
                        .buttonStyle(.plain)
                        .help(date.formatted(date: .abbreviated, time: .omitted))
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(height: 150)

            Divider()

            selectedDayDetail
        }
        .padding()
    }

    private var selectedDayDetail: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(selectedDate.formatted(date: .complete, time: .omitted))
                .font(.headline)

            let items = activeItems

            if items.isEmpty {
                Text("No reminder items")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(items) { item in
                    HStack {
                        Text(item.title)
                            .lineLimit(1)

                        Spacer()

                        Text(progressText(for: item))
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(height: 220)
    }

    private var activeItems: [ReminderItem] {
        settingsStore.items.filter { item in
            !item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private var firstDayOfDisplayedYear: Date {
        calendar.date(from: DateComponents(year: displayedYear, month: 1, day: 1)) ?? Date()
    }

    private var daysInDisplayedYear: [Date] {
        guard let start = calendar.date(from: DateComponents(year: displayedYear, month: 1, day: 1)),
              let end = calendar.date(from: DateComponents(year: displayedYear + 1, month: 1, day: 1)) else {
            return []
        }

        var dates: [Date] = []
        var current = start

        while current < end {
            dates.append(current)

            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else {
                break
            }

            current = next
        }

        return dates
    }

    private func dotColor(for date: Date) -> Color {
        if calendar.isDate(date, inSameDayAs: selectedDate) {
            return .accentColor
        }

        if achievementStore.hasCompletions(on: date) {
            return .green
        }

        return .secondary.opacity(0.35)
    }

    private func progressText(for item: ReminderItem) -> String {
        let completed = achievementStore.completionCount(for: item, on: selectedDate)
        let target = max(1, 1440 / max(item.intervalMinutes, 1))
        return "\(completed)/\(target)"
    }
}
