import Foundation
import SwiftUI

struct ReminderItem: Identifiable, Codable, Equatable {
    // Identifiable lets SwiftUI track each row in the reminder list.
    var id = UUID()

    var title: String
    var intervalMinutes: Int
}

final class ReminderSettingsStore: ObservableObject {
    // @Published tells SwiftUI to redraw the settings screen whenever items change.
    @Published var items: [ReminderItem] {
        didSet {
            save()
        }
    }

    private let storageKey = "reminderItems"
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults

        // UserDefaults is enough for this early version: it keeps settings after
        // relaunch without adding a database or file format yet.
        if let data = userDefaults.data(forKey: storageKey),
           let items = try? JSONDecoder().decode([ReminderItem].self, from: data) {
            self.items = items
        } else {
            self.items = [
                ReminderItem(title: "", intervalMinutes: 60)
            ]
        }
    }

    func addItem() {
        items.append(ReminderItem(title: "", intervalMinutes: 60))
    }

    func removeItem(_ item: ReminderItem) {
        items.removeAll { $0.id == item.id }
    }

    func removeItems(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else {
            return
        }

        userDefaults.set(data, forKey: storageKey)
    }
}

struct SettingsView: View {
    // ObservedObject means this view redraws when the shared settings store changes.
    @ObservedObject var store: ReminderSettingsStore
    @State private var isEditing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Reminders")
                    .font(AppFont.headline)

                Spacer()

                Button {
                    isEditing.toggle()
                } label: {
                    // Native macOS button labels do not always inherit the root
                    // SwiftUI font, so style this text explicitly.
                    Text(isEditing ? "Done" : "Edit")
                        .font(AppFont.body)
                }
                .buttonStyle(FixedGrayButtonStyle())
            }

            List {
                ForEach($store.items) { $item in
                    ReminderItemRow(
                        item: $item,
                        isEditing: isEditing,
                        onDelete: {
                            store.removeItem(item)
                        }
                    )
                    // Settings keeps the outer popover grey, but the editable
                    // reminder content itself should sit on white.
                    .listRowBackground(AppColors.dashboardBackground)
                }

                if isEditing {
                    Button {
                        store.addItem()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                            Text("Add reminder")
                                .font(AppFont.body)
                        }
                    }
                    .buttonStyle(FixedGrayButtonStyle())
                    .listRowBackground(AppColors.dashboardBackground)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.dashboardBackground)
        }
        .padding()
        .font(AppFont.body)
        .background(AppColors.panelBackground)
        .foregroundStyle(AppColors.primaryText)
        .preferredColorScheme(.light)
    }
}

private struct ReminderItemRow: View {
    // Each row edits one ReminderItem directly through a binding.
    @Binding var item: ReminderItem
    let isEditing: Bool
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if isEditing {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(FixedGrayButtonStyle())
                .foregroundStyle(.red)
            }

            VStack(alignment: .leading, spacing: 8) {
                if isEditing {
                    // Reminder contents are locked until the user explicitly
                    // enters edit mode.
                    TextField("What should Tide remind you about?", text: $item.title)
                        // TextField is AppKit-backed on macOS, so do not rely on
                        // inherited font styling from SettingsView.
                        .font(AppFont.body)
                } else {
                    HoverRevealText(text: item.title)
                }

                HStack {
                    Text("Every")
                        .font(AppFont.body)
                        .foregroundStyle(AppColors.secondaryText)

                    Stepper(
                        value: intervalStepperBinding,
                        in: 0...1440,
                        step: 5
                    ) {
                        HStack(spacing: 4) {
                            TextField(
                                "Minutes",
                                value: $item.intervalMinutes,
                                format: .number
                            )
                            .font(AppFont.body)
                            .frame(width: 40)
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
                            .disabled(!isEditing)
                            .onChange(of: item.intervalMinutes) { newValue in
                                item.intervalMinutes = min(max(newValue, 0), 1440)
                            }

                            Text("min")
                                .font(AppFont.body)
                                .foregroundStyle(AppColors.secondaryText)
                        }
                    }
                    .disabled(!isEditing)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var intervalStepperBinding: Binding<Int> {
        Binding(
            get: {
                item.intervalMinutes
            },
            set: { newValue in
                if newValue > item.intervalMinutes {
                    item.intervalMinutes = nextInterval(from: item.intervalMinutes)
                } else {
                    item.intervalMinutes = previousInterval(from: item.intervalMinutes)
                }
            }
        )
    }

    private func previousInterval(from value: Int) -> Int {
        if value <= 1 {
            return 0
        }

        let previousMultipleOfFive = ((value - 1) / 5) * 5
        return max(previousMultipleOfFive, 0)
    }

    private func nextInterval(from value: Int) -> Int {
        if value < 5 {
            return 5
        }

        let nextMultipleOfFive = ((value / 5) + 1) * 5
        return min(nextMultipleOfFive, 1440)
    }
}
