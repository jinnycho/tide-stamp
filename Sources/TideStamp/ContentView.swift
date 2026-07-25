import SwiftUI

struct ContentView: View {
    @ObservedObject var store: ReminderSettingsStore
    @ObservedObject var reminderTimer: ReminderTimer
    @ObservedObject var achievementStore: AchievementStore
    @ObservedObject var presentationState: PopoverPresentationState

    // AppKit owns popover placement, so SwiftUI reports the button click upward.
    let onSettingsButtonClicked: () -> Void
    let onDashboardButtonClicked: () -> Void

    var body: some View {
        HomeView(
            items: store.items,
            reminderTimer: reminderTimer,
            achievementStore: achievementStore,
            presentationState: presentationState,
            onSettingsButtonClicked: onSettingsButtonClicked,
            onDashboardButtonClicked: onDashboardButtonClicked
        )
        .frame(width: 280, height: 220)
        .font(AppFont.body)
        .background(AppColors.panelBackground)
        .foregroundStyle(AppColors.primaryText)
        .preferredColorScheme(.light)
    }
}

private struct HomeView: View {
    let items: [ReminderItem]
    @ObservedObject var reminderTimer: ReminderTimer
    @ObservedObject var achievementStore: AchievementStore
    @ObservedObject var presentationState: PopoverPresentationState
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
            HStack(spacing: 6) {
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
                            .fill(
                                selectedTab == tab
                                    ? AppColors.selectedControlBackground
                                    : AppColors.controlBackground
                            )
                    }
                }
            }
            .padding(2)
            .background {
                RoundedRectangle(cornerRadius: 6)
                    // Todo/Ticking should stay slightly darker than the fixed
                    // ECEEF0 panel even when macOS switches appearance.
                    .fill(AppColors.controlBackground)
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
                .buttonStyle(FixedGrayButtonStyle(isActive: presentationState.isDashboardShown))

                Button(action: onSettingsButtonClicked) {
                    Label("Settings", systemImage: "gearshape")
                }
                .buttonStyle(FixedGrayButtonStyle(isActive: presentationState.isSettingsShown))
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
                .foregroundStyle(AppColors.secondaryText)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(items) { item in
                Button {
                    achievementStore.recordCompletion(for: item)
                    reminderTimer.completeTodo(for: item)
                } label: {
                    HStack {
                        Image(systemName: "circle")
                        HoverRevealText(text: item.title)
                    }
                }
                .buttonStyle(.plain)
                .padding(.vertical, 2)
                .listRowBackground(AppColors.panelBackground)
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.panelBackground)
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
                .foregroundStyle(AppColors.secondaryText)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(items) { item in
                HStack(spacing: 3) {
                    HoverRevealText(text: item.title)

                    Spacer()

                    Text(timeRemainingText(item))
                        .font(AppFont.body)
                        .foregroundStyle(AppColors.secondaryText)
                        .monospacedDigit()

                    Button {
                        onRefresh(item)
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(CompactIconButtonStyle())
                }
                // Keep ticking rows compact horizontally so longer reminder names
                // have as much room as possible in the small Home popover.
                .padding(.vertical, 0)
                .listRowInsets(EdgeInsets(top: 2, leading: 2, bottom: 2, trailing: 2))
                // Ticking's actual reminder rows should read as content, so keep
                // them white against the fixed grey app panel.
                .listRowBackground(AppColors.dashboardBackground)
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.dashboardBackground)
        }
    }
}
