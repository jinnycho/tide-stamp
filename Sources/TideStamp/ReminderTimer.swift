import Foundation

final class ReminderTimer: ObservableObject {
    @Published private var now = Date()
    @Published private(set) var dueItemIDs: Set<UUID> = []
    @Published private var dueDates: [UUID: Date] = [:]

    private var tickTimer: Timer?
    private var itemsByID: [UUID: ReminderItem] = [:]
    private let onReminderReleased: (ReminderItem) -> Void

    init(onReminderReleased: @escaping (ReminderItem) -> Void = { _ in }) {
        self.onReminderReleased = onReminderReleased
    }

    func restart(with items: [ReminderItem]) {
        stop()

        let activeItems = items.filter { item in
            let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
            return !title.isEmpty
        }

        now = Date()
        dueItemIDs = dueItemIDs.intersection(activeItems.map(\.id))
        itemsByID = Dictionary(uniqueKeysWithValues: activeItems.map { ($0.id, $0) })
        dueDates = Dictionary(uniqueKeysWithValues: activeItems.map { item in
            (item.id, now.addingTimeInterval(TimeInterval(item.intervalMinutes * 60)))
        })

        guard !activeItems.isEmpty else {
            return
        }

        tickTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func stop() {
        tickTimer?.invalidate()
        tickTimer = nil
        dueDates.removeAll()
        itemsByID.removeAll()
    }

    func completeTodo(for item: ReminderItem) {
        dueItemIDs.remove(item.id)
    }

    func refresh(item: ReminderItem) {
        dueDates[item.id] = Date().addingTimeInterval(TimeInterval(item.intervalMinutes * 60))
    }

    func secondsRemaining(for item: ReminderItem) -> Int? {
        guard let dueDate = dueDates[item.id] else {
            return nil
        }

        return max(0, Int(ceil(dueDate.timeIntervalSince(now))))
    }

    private func tick() {
        now = Date()

        for (id, dueDate) in dueDates where dueDate <= now {
            guard let item = itemsByID[id] else {
                continue
            }

            dueItemIDs.insert(id)
            onReminderReleased(item)

            // Once an item is due, roll its next due time forward so the
            // countdown keeps showing the next interval.
            dueDates[id] = now.addingTimeInterval(TimeInterval(item.intervalMinutes * 60))
        }
    }
}
