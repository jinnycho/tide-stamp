import CoreGraphics
import Foundation

final class ReminderTimer: ObservableObject {
    @Published private var now = Date()
    @Published private(set) var dueItemIDs: Set<UUID> = []
    @Published private var dueDates: [UUID: Date] = [:]
    @Published private(set) var isPaused = false

    private var tickTimer: Timer?
    private var itemsByID: [UUID: ReminderItem] = [:]
    private var lastTickDate = Date()
    private var pausedAt: Date?
    private let sleepGapThreshold: TimeInterval = 15
    private let displaySleepIdleThreshold: TimeInterval = 10 * 60
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
                    let previousDueDate
                {
                    return (item.id, previousDueDate)
                }

                return (item.id, nextDueDate(for: item))
            }
        )

        stopTickTimer()

        guard !activeItems.isEmpty, !isPaused else {
            return
        }

        startTickTimer()
    }

    private func nextDueDate(for item: ReminderItem) -> Date {
        // 0 minutes is a temporary fast interval for testing reminders.
        Date().addingTimeInterval(
            item.intervalMinutes == 0 ? 10 : TimeInterval(item.intervalMinutes * 60))
    }

    func stop() {
        stopTickTimer()
        dueDates.removeAll()
        itemsByID.removeAll()
        pausedAt = nil
        isPaused = false
    }

    func pause() {
        guard !isPaused else {
            return
        }

        // Preserve current due dates and todos, but stop the repeating timer so
        // no release callbacks, badge updates, or burst notifications happen.
        now = Date()
        pausedAt = now
        isPaused = true
        stopTickTimer()
    }

    func resume() {
        guard isPaused else {
            return
        }

        let resumedAt = Date()

        if let pausedAt {
            let pausedDuration = resumedAt.timeIntervalSince(pausedAt)
            // Pause should freeze ticking time. Shift due dates forward by the
            // full paused duration so reminders do not become due while paused.
            dueDates = dueDates.mapValues { dueDate in
                dueDate.addingTimeInterval(pausedDuration)
            }
        }

        now = resumedAt
        lastTickDate = resumedAt
        pausedAt = nil
        isPaused = false

        if !itemsByID.isEmpty {
            startTickTimer()
        }
    }

    func togglePause() {
        isPaused ? resume() : pause()
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
        guard !isPaused else {
            return
        }

        let currentDate = Date()
        let elapsedSinceLastTick = currentDate.timeIntervalSince(lastTickDate)

        if elapsedSinceLastTick > sleepGapThreshold || shouldTreatDisplayAsInactive {
            // Timer callbacks pause while the laptop sleeps. When the app wakes,
            // or when the display is black while the app remains awake, shift
            // due dates forward by the inactive gap so counts represent visible
            // reminder time.
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
            // 0 minutes is a temporary fast interval for testing reminders.
            dueDates[id] = now.addingTimeInterval(
                item.intervalMinutes == 0 ? 10 : TimeInterval(item.intervalMinutes * 60))
        }
    }

    private var shouldTreatDisplayAsInactive: Bool {
        secondsSinceLastUserInput > displaySleepIdleThreshold && isMainDisplayAsleep
    }

    private var isMainDisplayAsleep: Bool {
        CGDisplayIsAsleep(CGMainDisplayID()) != 0
    }

    private var secondsSinceLastUserInput: TimeInterval {
        let inputEventTypes: [CGEventType] = [
            .leftMouseDown,
            .rightMouseDown,
            .otherMouseDown,
            .leftMouseDragged,
            .rightMouseDragged,
            .otherMouseDragged,
            .mouseMoved,
            .scrollWheel,
            .keyDown
        ]

        // CoreGraphics reports idle time by event type, so use the most recent
        // common input event as the app's practical activity signal. This value
        // only gates a display-sleep check; idle time alone never pauses counts.
        return inputEventTypes
            .map {
                CGEventSource.secondsSinceLastEventType(
                    .combinedSessionState,
                    eventType: $0
                )
            }
            .min() ?? 0
    }

    private func startTickTimer() {
        stopTickTimer()
        tickTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func stopTickTimer() {
        tickTimer?.invalidate()
        tickTimer = nil
    }
}
