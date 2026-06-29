import SwiftUI

struct DashboardView: View {
    @ObservedObject var settingsStore: ReminderSettingsStore
    @ObservedObject var achievementStore: AchievementStore

    @State private var displayedYear = Calendar.current.component(.year, from: Date())
    @State private var selectedDate = Date()

    private let calendar = Calendar.current
    private let dayColumns = Array(repeating: GridItem(.fixed(12), spacing: 5), count: 31)
    private let monthLabelWidth: CGFloat = 14

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

            VStack(alignment: .leading, spacing: 6) {
                ForEach(monthsInDisplayedYear, id: \.month) { month in
                    HStack(spacing: 6) {
                        Text("\(month.month)")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: monthLabelWidth, alignment: .trailing)

                        LazyVGrid(columns: dayColumns, alignment: .leading, spacing: 5) {
                            ForEach(month.days, id: \.self) { date in
                                Button {
                                    selectedDate = date
                                } label: {
                                    Circle()
                                        .fill(dotColor(for: date))
                                        .frame(width: 6, height: 6)
                                        .frame(width: 12, height: 12)
                                }
                                .buttonStyle(.plain)
                                .help(date.formatted(date: .abbreviated, time: .omitted))
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 2)

            Divider()

            selectedDayDetail
        }
        .padding()
    }

    private var selectedDayDetail: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(selectedDate.formatted(date: .complete, time: .omitted))
                .font(.headline)

            let items = achievementStore.trackedItemsWithProgress(on: selectedDate)

            if items.isEmpty {
                Text("No reminder items")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(items) { item in
                            HStack {
                                Text(item.title)
                                    .lineLimit(1)

                                Spacer()

                                Text(progressText(for: item))
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
        }
        .frame(height: 110)
    }

    private var firstDayOfDisplayedYear: Date {
        calendar.date(from: DateComponents(year: displayedYear, month: 1, day: 1)) ?? Date()
    }

    private var monthsInDisplayedYear: [MonthDays] {
        (1...12).map { month in
            let start = calendar.date(from: DateComponents(year: displayedYear, month: month, day: 1)) ?? Date()
            let range = calendar.range(of: .day, in: .month, for: start) ?? 1..<1
            let days = range.compactMap { day in
                calendar.date(from: DateComponents(year: displayedYear, month: month, day: day))
            }

            return MonthDays(
                month: month,
                days: days
            )
        }
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

    private func progressText(for item: TrackedReminderItem) -> String {
        let progress = achievementStore.progress(for: item, on: selectedDate)
        return "\(progress.completed)/\(progress.released)"
    }
}

private struct MonthDays {
    let month: Int
    let days: [Date]
}
