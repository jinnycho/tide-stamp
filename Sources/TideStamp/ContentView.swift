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
        .background(Color.white)
        .preferredColorScheme(.light)
        .font(AppFont.body)
    }
}

private struct HomeView: View {
    let items: [ReminderItem]
    @ObservedObject var reminderTimer: ReminderTimer
    @ObservedObject var achievementStore: AchievementStore
    @State private var selectedTab = HomeTab.todo

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
            // Use a SwiftUI-built switcher instead of TabView so the Todo/Ticking
            // labels use the bundled Tabular font instead of AppKit's tab font.
            HStack(spacing: 4) {
                ForEach(HomeTab.allCases) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        Text(tab.title)
                            .font(selectedTab == tab ? AppFont.headline : AppFont.body)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .background {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(selectedTab == tab ? Color.accentColor.opacity(0.14) : .clear)
                    }
                }
            }
            .padding(2)
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.secondary.opacity(0.08))
            }

            Group {
                switch selectedTab {
                case .todo:
                    TodoListView(
                        items: dueItems,
                        reminderTimer: reminderTimer,
                        achievementStore: achievementStore
                    )
                case .ticking:
                    TickingListView(
                        items: visibleItems,
                        timeRemainingText: timeRemainingText,
                        onRefresh: reminderTimer.refresh
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

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

private enum HomeTab: CaseIterable, Identifiable {
    case todo
    case ticking

    var id: Self { self }

    var title: String {
        switch self {
        case .todo:
            return "Todo"
        case .ticking:
            return "Ticking"
        }
    }
}

private struct TodoListView: View {
    let items: [ReminderItem]
    @ObservedObject var reminderTimer: ReminderTimer
    @ObservedObject var achievementStore: AchievementStore

    var body: some View {
        if items.isEmpty {
            Text("Nothing due")
                .font(AppFont.body)
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
                            .font(AppFont.body)
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
    let onRefresh: (ReminderItem) -> Void

    var body: some View {
        if items.isEmpty {
            Text("No reminders")
                .font(AppFont.body)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(items) { item in
                HStack {
                    Text(item.title)
                        .font(AppFont.body)
                        .lineLimit(1)

                    Spacer()

                    Text(timeRemainingText(item))
                        .font(AppFont.body)
                        .foregroundStyle(.secondary)

                    Button {
                        onRefresh(item)
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                }
                .padding(.vertical, 2)
            }
        }
    }
}
