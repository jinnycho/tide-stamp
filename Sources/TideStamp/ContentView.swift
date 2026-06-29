import SwiftUI

struct ContentView: View {
    @ObservedObject var store: ReminderSettingsStore
    @ObservedObject var reminderTimer: ReminderTimer
    @ObservedObject var achievementStore: AchievementStore

    // AppKit owns popover placement, so SwiftUI reports the button click upward.
    let onSettingsButtonClicked: () -> Void
    let onDashboardButtonClicked: () -> Void

    var body: some View {
        HomeView(
            items: store.items,
            reminderTimer: reminderTimer,
            achievementStore: achievementStore,
            onSettingsButtonClicked: onSettingsButtonClicked,
            onDashboardButtonClicked: onDashboardButtonClicked
        )
        .frame(width: 280, height: 220)
    }
}

private struct HomeView: View {
    let items: [ReminderItem]
    @ObservedObject var reminderTimer: ReminderTimer
    @ObservedObject var achievementStore: AchievementStore

    // This callback keeps HomeView simple: it does not need to know whether
    // settings appears in another popover, window, or future navigation screen.
    let onSettingsButtonClicked: () -> Void
    let onDashboardButtonClicked: () -> Void

    private var visibleItems: [ReminderItem] {
        items.filter { item in
            !item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TabView {
                TodoListView(
                    items: dueItems,
                    reminderTimer: reminderTimer,
                    achievementStore: achievementStore
                )
                    .tabItem { Text("Todo") }

                TickingListView(
                    items: visibleItems,
                    timeRemainingText: timeRemainingText
                )
                .tabItem { Text("Ticking") }
            }

            HStack {
                Button(action: onDashboardButtonClicked) {
                    Label("Dashboard", systemImage: "chart.dots.scatter")
                }

                Button(action: onSettingsButtonClicked) {
                    Label("Settings", systemImage: "gearshape")
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var dueItems: [ReminderItem] {
        visibleItems.filter { item in
            reminderTimer.dueItemIDs.contains(item.id)
        }
    }

    private func timeRemainingText(for item: ReminderItem) -> String {
        guard let seconds = reminderTimer.secondsRemaining(for: item) else {
            return "--:--"
        }

        let minutes = seconds / 60
        let remainingSeconds = seconds % 60

        if minutes >= 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return "\(hours)h \(remainingMinutes)m"
        }

        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
}

private struct TodoListView: View {
    let items: [ReminderItem]
    @ObservedObject var reminderTimer: ReminderTimer
    @ObservedObject var achievementStore: AchievementStore

    var body: some View {
        if items.isEmpty {
            Text("Nothing due")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(items) { item in
                Button {
                    achievementStore.recordCompletion(for: item)
                    reminderTimer.completeTodo(for: item)
                } label: {
                    HStack {
                        Image(systemName: "circle")
                        Text(item.title)
                            .lineLimit(1)
                    }
                }
                .buttonStyle(.plain)
                .padding(.vertical, 2)
            }
        }
    }
}

private struct TickingListView: View {
    let items: [ReminderItem]
    let timeRemainingText: (ReminderItem) -> String

    var body: some View {
        if items.isEmpty {
            Text("No reminders")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(items) { item in
                HStack {
                    Text(item.title)
                        .lineLimit(1)

                    Spacer()

                    Text(timeRemainingText(item))
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }
        }
    }
}
