import SwiftUI

struct ContentView: View {
    @ObservedObject var store: ReminderSettingsStore
    @ObservedObject var reminderTimer: ReminderTimer

    // AppKit owns popover placement, so SwiftUI reports the button click upward.
    let onSettingsButtonClicked: () -> Void

    var body: some View {
        HomeView(
            items: store.items,
            reminderTimer: reminderTimer,
            onSettingsButtonClicked: onSettingsButtonClicked
        )
        .frame(width: 280, height: 220)
    }
}

private struct HomeView: View {
    let items: [ReminderItem]
    @ObservedObject var reminderTimer: ReminderTimer

    // This callback keeps HomeView simple: it does not need to know whether
    // settings appears in another popover, window, or future navigation screen.
    let onSettingsButtonClicked: () -> Void

    private var visibleItems: [ReminderItem] {
        items.filter { item in
            !item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if visibleItems.isEmpty {
                Text("No reminders")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(visibleItems) { item in
                    HStack {
                        Text(item.title)
                            .lineLimit(1)

                        Spacer()

                        Text(timeRemainingText(for: item))
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }

            Button(action: onSettingsButtonClicked) {
                Label("Settings", systemImage: "gearshape")
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
