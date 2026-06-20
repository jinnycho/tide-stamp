import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let homePopover = NSPopover()
    private let settingsPopover = NSPopover()
    private let settingsStore = ReminderSettingsStore()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // ContentView owns the small "hi" UI. AppDelegate owns popover placement
        // because popovers are an AppKit concept, not a SwiftUI concept.
        let contentView = ContentView { [weak self] in
            self?.toggleSettingsPopover()
        }

        // The home popover stays small forever; opening settings should not
        // resize or visually stretch this screen.
        homePopover.contentSize = NSSize(width: 180, height: 110)
        homePopover.behavior = .transient
        homePopover.contentViewController = NSHostingController(rootView: contentView)

        // Settings gets its own popover so it has a separate border/background
        // instead of sharing one expanded container with the "hi" screen.
        settingsPopover.contentSize = NSSize(width: 380, height: 320)
        settingsPopover.behavior = .transient
        settingsPopover.contentViewController = NSHostingController(rootView: SettingsView(store: settingsStore))

        // NSStatusItem is the actual button that appears in the macOS menu bar.
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "Tide"
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover)

        self.statusItem = statusItem
    }

    @objc private func togglePopover() {
        // The popover needs the status bar button as its anchor point.
        guard let button = statusItem?.button else {
            return
        }

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
}

let app = NSApplication.shared
let delegate = AppDelegate()

app.delegate = delegate

// Keep Tide Stamp out of the Dock because it is meant to live in the menu bar.
app.setActivationPolicy(.accessory)
app.run()
