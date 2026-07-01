import Foundation

final class ReminderTimer: ObservableObject {
    @Published private var now = Date()
    @Published private(set) var dueItemIDs: Set<UUID> = []
    @Published private var dueDates: [UUID: Date] = [:]

    private var tickTimer: Timer?
    private var itemsByID: [UUID: ReminderItem] = [:]
    private var lastTickDate = Date()
    private let sleepGapThreshold: TimeInterval = 15
    private let onReminderReleased: (ReminderItem) -> Void

    init(onReminderReleased: @escaping (ReminderItem) -> Void = { _ in }) {
        self.onReminderReleased = onReminderReleased
    }

    func restart(with items: [ReminderItem]) {
        let activeItems = items.filter { item in
            let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
            return !title.isEmpty
        }
        let activeIDs = Set(activeItems.map(\.id))
        let previousItemsByID = itemsByID
        let previousDueDates = dueDates

        now = Date()
        lastTickDate = now
        dueItemIDs = dueItemIDs.intersection(activeIDs)
        itemsByID = Dictionary(uniqueKeysWithValues: activeItems.map { ($0.id, $0) })
        dueDates = Dictionary(
            uniqueKeysWithValues: activeItems.map { item in
                let previousItem = previousItemsByID[item.id]
                let previousDueDate = previousDueDates[item.id]

                if previousItem?.intervalMinutes == item.intervalMinutes,
                   let previousDueDate {
                    return (item.id, previousDueDate)
                }

                return (item.id, nextDueDate(for: item))
            }
        )

        tickTimer?.invalidate()
        tickTimer = nil

        guard !activeItems.isEmpty else {
            return
        }

        tickTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func nextDueDate(for item: ReminderItem) -> Date {
        Date().addingTimeInterval(TimeInterval(item.intervalMinutes * 60))
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
        dueDates[item.id] = nextDueDate(for: item)
        lastTickDate = Date()
    }

    func secondsRemaining(for item: ReminderItem) -> Int? {
        guard let dueDate = dueDates[item.id] else {
            return nil
        }

        return max(0, Int(ceil(dueDate.timeIntervalSince(now))))
    }

    private func tick() {
        let currentDate = Date()
        let elapsedSinceLastTick = currentDate.timeIntervalSince(lastTickDate)

        if elapsedSinceLastTick > sleepGapThreshold {
            // Timer callbacks pause while the laptop sleeps. When the app wakes,
            // shift due dates forward by the inactive gap so we only count
            // reminders that had a chance to appear while the laptop was awake.
            dueDates = dueDates.mapValues { dueDate in
                dueDate.addingTimeInterval(elapsedSinceLastTick)
            }
            now = currentDate
            lastTickDate = currentDate
            return
        }

        now = currentDate
        lastTickDate = currentDate

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
