import AppKit
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let homePopover = NSPopover()
    private let settingsPopover = NSPopover()
    private let dashboardPopover = NSPopover()
    private var reminderBurstPanel: NSPanel?
    private let settingsStore = ReminderSettingsStore()
    private let achievementStore = AchievementStore()
    private var reminderTimer: ReminderTimer?
    private var cancellables = Set<AnyCancellable>()
    private var isShowingReminderDot = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        let reminderTimer = ReminderTimer { [weak self] item in
            // This callback fires for every reminder release, even when an older
            // due item is still unchecked. Keep the large burst tied to the
            // release event itself instead of the aggregate due/non-due state.
            self?.achievementStore.recordRelease(for: item)
            self?.showReminderBurst()
        }
        self.reminderTimer = reminderTimer

        // ContentView owns the small "hi" UI. AppDelegate owns popover placement
        // because popovers are an AppKit concept, not a SwiftUI concept.
        let contentView = ContentView(
            store: settingsStore,
            reminderTimer: reminderTimer,
            achievementStore: achievementStore
        ) { [weak self] in
            self?.toggleSettingsPopover()
        } onDashboardButtonClicked: { [weak self] in
            self?.toggleDashboardPopover()
        }

        homePopover.contentSize = NSSize(width: 280, height: 220)
        homePopover.behavior = .transient
        homePopover.contentViewController = NSHostingController(rootView: contentView)

        // Settings gets its own popover so it has a separate border/background
        // instead of sharing one expanded container with the "hi" screen.
        settingsPopover.contentSize = NSSize(width: 380, height: 320)
        settingsPopover.behavior = .transient
        settingsPopover.contentViewController = NSHostingController(rootView: SettingsView(store: settingsStore))

        dashboardPopover.contentSize = NSSize(width: 460, height: 470)
        dashboardPopover.behavior = .transient
        dashboardPopover.contentViewController = NSHostingController(
            rootView: DashboardView(settingsStore: settingsStore, achievementStore: achievementStore)
        )

        // NSStatusItem is the actual button that appears in the macOS menu bar.
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.imagePosition = .imageOnly
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover)

        self.statusItem = statusItem
        updateStatusItemBadge()

        reminderTimer.restart(with: settingsStore.items)
        achievementStore.syncDeletedItems(currentItems: settingsStore.items)

        settingsStore.$items
            .receive(on: RunLoop.main)
            .sink { [weak self] items in
                self?.isShowingReminderDot = false
                self?.updateStatusItemBadge()
                self?.achievementStore.syncDeletedItems(currentItems: items)
                self?.reminderTimer?.restart(with: items)
            }
            .store(in: &cancellables)

        reminderTimer.$dueItemIDs
            .receive(on: RunLoop.main)
            .sink { [weak self] dueItemIDs in
                // The menu-bar dot represents whether anything is currently due.
                // The large reminder burst is handled by ReminderTimer's release
                // callback so repeated releases still animate while todos remain.
                self?.isShowingReminderDot = !dueItemIDs.isEmpty
                self?.updateStatusItemBadge()
            }
            .store(in: &cancellables)
    }

    @objc private func togglePopover() {
        // The popover needs the status bar button as its anchor point.
        guard let button = statusItem?.button else {
            return
        }

        if homePopover.isShown {
            settingsPopover.performClose(nil)
            dashboardPopover.performClose(nil)
            homePopover.performClose(nil)
        } else {
            homePopover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    @objc private func toggleSettingsPopover() {
        if settingsPopover.isShown {
            settingsPopover.performClose(nil)
            dashboardPopover.performClose(nil)
            return
        }

        guard homePopover.isShown,
              let homeView = homePopover.contentViewController?.view else {
            return
        }

        dashboardPopover.performClose(nil)

        // Anchor settings to the left edge of the home popover. This makes it
        // feel like a separate nearby screen instead of one larger shared view.
        settingsPopover.show(
            relativeTo: homeView.bounds,
            of: homeView,
            preferredEdge: .minX
        )
    }

    @objc private func toggleDashboardPopover() {
        if dashboardPopover.isShown {
            dashboardPopover.performClose(nil)
            settingsPopover.performClose(nil)
            return
        }

        guard homePopover.isShown,
              let homeView = homePopover.contentViewController?.view else {
            return
        }

        settingsPopover.performClose(nil)

        let positioningRect = homeView.bounds.offsetBy(dx: -180, dy: 0)

        dashboardPopover.show(
            relativeTo: positioningRect,
            of: homeView,
            preferredEdge: .minX
        )
    }

    private func showReminderBurst() {
        guard let button = statusItem?.button else {
            return
        }

        let panelSize = NSSize(
            width: ReminderBurstView.displaySize,
            height: ReminderBurstView.displaySize
        )
        let screenFrame = button.window?.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        let topRightMargin: CGFloat = 16
        let panelOrigin = NSPoint(
            // Put the animation near the top-right of the active laptop screen
            // instead of attaching it to the menu-bar status item.
            x: screenFrame.maxX - panelSize.width - topRightMargin,
            y: screenFrame.maxY - panelSize.height - topRightMargin
        )

        reminderBurstPanel?.close()

        let panel = NSPanel(
            contentRect: NSRect(origin: panelOrigin, size: panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.level = .statusBar
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .transient]

        let hostingView = NSHostingView(rootView: ReminderBurstView())
        hostingView.frame = NSRect(origin: .zero, size: panelSize)
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentView = hostingView
        panel.orderFrontRegardless()

        reminderBurstPanel = panel

        DispatchQueue.main.asyncAfter(deadline: .now() + ReminderBurstView.animationDuration) { [weak self] in
            self?.reminderBurstPanel?.close()
            self?.reminderBurstPanel = nil
        }
    }

    private func updateStatusItemBadge() {
        statusItem?.button?.image = StatusItemBadge.image(isShowingDot: isShowingReminderDot)
        statusItem?.button?.toolTip = isShowingReminderDot ? "Reminder due" : nil
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()

app.delegate = delegate

// Keep Tide Stamp out of the Dock because it is meant to live in the menu bar.
app.setActivationPolicy(.accessory)
app.run()
