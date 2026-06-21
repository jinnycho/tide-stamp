import AppKit
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let homePopover = NSPopover()
    private let settingsPopover = NSPopover()
    private let settingsStore = ReminderSettingsStore()
    private var reminderTimer: ReminderTimer?
    private var cancellables = Set<AnyCancellable>()
    private var isShowingReminderDot = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        let reminderTimer = ReminderTimer { [weak self] in
            self?.showReminderDot()
        }
        self.reminderTimer = reminderTimer

        // ContentView owns the small "hi" UI. AppDelegate owns popover placement
        // because popovers are an AppKit concept, not a SwiftUI concept.
        let contentView = ContentView(
            store: settingsStore,
            reminderTimer: reminderTimer
        ) { [weak self] in
            self?.toggleSettingsPopover()
        }

        homePopover.contentSize = NSSize(width: 280, height: 220)
        homePopover.behavior = .transient
        homePopover.contentViewController = NSHostingController(rootView: contentView)

        // Settings gets its own popover so it has a separate border/background
        // instead of sharing one expanded container with the "hi" screen.
        settingsPopover.contentSize = NSSize(width: 380, height: 320)
        settingsPopover.behavior = .transient
        settingsPopover.contentViewController = NSHostingController(rootView: SettingsView(store: settingsStore))

        // NSStatusItem is the actual button that appears in the macOS menu bar.
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.imagePosition = .imageOnly
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover)

        self.statusItem = statusItem
        updateStatusItemBadge()

        reminderTimer.restart(with: settingsStore.items)

        settingsStore.$items
            .receive(on: RunLoop.main)
            .sink { [weak self] items in
                self?.isShowingReminderDot = false
                self?.updateStatusItemBadge()
                self?.reminderTimer?.restart(with: items)
            }
            .store(in: &cancellables)
    }

    @objc private func togglePopover() {
        // The popover needs the status bar button as its anchor point.
        guard let button = statusItem?.button else {
            return
        }

        isShowingReminderDot = false
        updateStatusItemBadge()

        if homePopover.isShown {
            settingsPopover.performClose(nil)
            homePopover.performClose(nil)
        } else {
            homePopover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    @objc private func toggleSettingsPopover() {
        if settingsPopover.isShown {
            settingsPopover.performClose(nil)
            return
        }

        guard homePopover.isShown,
              let homeView = homePopover.contentViewController?.view else {
            return
        }

        // Anchor settings to the right edge of the home popover. This makes it
        // feel like a separate nearby screen instead of one larger shared view.
        settingsPopover.show(
            relativeTo: homeView.bounds,
            of: homeView,
            preferredEdge: .maxX
        )
    }

    private func showReminderDot() {
        DispatchQueue.main.async { [weak self] in
            self?.isShowingReminderDot = true
            self?.updateStatusItemBadge()
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
