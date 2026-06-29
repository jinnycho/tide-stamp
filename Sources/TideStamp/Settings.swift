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
                    .font(.headline)

                Spacer()

                Button(isEditing ? "Done" : "Edit") {
                    isEditing.toggle()
                }
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
                }

                if isEditing {
                    Button {
                        store.addItem()
                    } label: {
                        Label("Add reminder", systemImage: "plus")
                    }
                }
            }
        }
        .padding()
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
                .buttonStyle(.borderless)
                .foregroundStyle(.red)
            }

            VStack(alignment: .leading, spacing: 8) {
                // Reminder contents are locked until the user explicitly enters edit mode.
                TextField("What should Tide remind you about?", text: $item.title)
                    .disabled(!isEditing)

                HStack {
                    Text("Every")
                        .foregroundStyle(.secondary)

                    Stepper(
                        value: intervalStepperBinding,
                        in: 1...1440,
                        step: 5
                    ) {
                        HStack(spacing: 4) {
                            TextField(
                                "Minutes",
                                value: $item.intervalMinutes,
                                format: .number
                            )
                            .frame(width: 40)
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
                            .disabled(!isEditing)
                            .onChange(of: item.intervalMinutes) { newValue in
                                item.intervalMinutes = min(max(newValue, 1), 1440)
                            }

                            Text("min")
                                .foregroundStyle(.secondary)
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
        if value <= 5 {
            return 1
        }

        let previousMultipleOfFive = ((value - 1) / 5) * 5
        return max(previousMultipleOfFive, 1)
    }

    private func nextInterval(from value: Int) -> Int {
        if value < 5 {
            return 5
        }

        let nextMultipleOfFive = ((value / 5) + 1) * 5
        return min(nextMultipleOfFive, 1440)
    }
}
