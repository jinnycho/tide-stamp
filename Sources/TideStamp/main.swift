import AppKit
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let homePopover = NSPopover()
    private let settingsPopover = NSPopover()
    private let dashboardPopover = NSPopover()
    private let dailyDetailsPopover = NSPopover()
    private var quitMenuPanel: NSPanel?
    private var reminderBurstPanel: NSPanel?
    private var localMouseMonitor: Any?
    private var globalMouseMonitor: Any?
    private let settingsStore = ReminderSettingsStore()
    private let achievementStore = AchievementStore()
    private let dailyDetailsSelection = DailyDetailsSelection()
    private let presentationState = PopoverPresentationState()
    private var reminderTimer: ReminderTimer?
    private var cancellables = Set<AnyCancellable>()
    private var isShowingReminderDot = false
    private let compactPopoverSize = NSSize(width: 280, height: 220)

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppFont.registerBundledFonts()

        let reminderTimer = ReminderTimer { [weak self] item in
            // This callback fires for every reminder release, even when an older
            // due item is still unchecked. Keep the large burst tied to the
            // release event itself instead of the aggregate due/non-due state.
            self?.achievementStore.recordRelease(for: item)
            self?.showReminderBurst(for: item)
        }
        self.reminderTimer = reminderTimer

        // ContentView owns the small "hi" UI. AppDelegate owns popover placement
        // because popovers are an AppKit concept, not a SwiftUI concept.
        let contentView = ContentView(
            store: settingsStore,
            reminderTimer: reminderTimer,
            achievementStore: achievementStore,
            presentationState: presentationState
        ) { [weak self] in
            self?.toggleSettingsPopover()
        } onDashboardButtonClicked: { [weak self] in
            self?.toggleDashboardPopover()
        }

        homePopover.contentSize = compactPopoverSize
        // All app popovers use application-defined behavior so clicks between Home,
        // Dashboard, Settings, and Daily Details do not make AppKit close one
        // surface while another app surface is handling the same interaction.
        // Outside-app dismissal is handled explicitly by the mouse monitors below.
        homePopover.behavior = .applicationDefined
        homePopover.contentViewController = NSHostingController(rootView: contentView)

        // Settings gets its own popover so it has a separate border/background
        // instead of sharing one expanded container with the "hi" screen.
        settingsPopover.contentSize = NSSize(width: 380, height: 320)
        settingsPopover.behavior = .applicationDefined
        settingsPopover.contentViewController = NSHostingController(
            rootView: SettingsView(store: settingsStore))

        dashboardPopover.contentSize = NSSize(width: 530, height: 450)
        // Keep Dashboard open when reward clicks open the companion details
        // popover. AppKit's transient/semitransient modes can dismiss the first
        // popover while the second one is being shown.
        dashboardPopover.behavior = .applicationDefined
        dashboardPopover.contentViewController = NSHostingController(
            rootView: DashboardView(
                achievementStore: achievementStore,
                presentationState: presentationState
            ) { [weak self] date in
                self?.showDailyDetails(for: date)
            }
        )

        // Daily details match Home's size so the selected day reads as a
        // companion panel below Todo/Ticking instead of part of the dashboard.
        dailyDetailsPopover.contentSize = compactPopoverSize
        // Match Dashboard's behavior so users can move between calendar and
        // details without AppKit automatically dismissing either related popover.
        dailyDetailsPopover.behavior = .applicationDefined
        // Keep one fixed-size hosting controller for Daily Details. Replacing a
        // shown popover's controller lets AppKit briefly resize from the new
        // SwiftUI view's intrinsic size before contentSize is applied again.
        dailyDetailsPopover.contentViewController = NSHostingController(
            rootView: DailyDetailsContainerView(
                achievementStore: achievementStore,
                selection: dailyDetailsSelection,
                size: compactPopoverSize
            )
        )

        // NSStatusItem is the actual button that appears in the macOS menu bar.
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.imagePosition = .imageOnly
        statusItem.button?.target = self
        statusItem.button?.action = #selector(handleStatusItemClick)
        // The menu bar icon uses left click for Home and right click for the
        // lightweight app menu, so ask AppKit to deliver both as button actions.
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])

        self.statusItem = statusItem
        updateStatusItemBadge()
        installOutsideClickMonitors()

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

    func applicationWillTerminate(_ notification: Notification) {
        removeOutsideClickMonitors()
    }

    @objc private func handleStatusItemClick() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showStatusItemMenu()
            return
        }

        togglePopover()
    }

    private func togglePopover() {
        // The popover needs the status bar button as its anchor point.
        guard let button = statusItem?.button else {
            return
        }

        if homePopover.isShown {
            closeOpenSurfaces()
        } else {
            homePopover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    @objc private func toggleSettingsPopover() {
        if settingsPopover.isShown {
            settingsPopover.performClose(nil)
            dashboardPopover.performClose(nil)
            dailyDetailsPopover.performClose(nil)
            presentationState.isSettingsShown = false
            presentationState.isDashboardShown = false
            return
        }

        guard homePopover.isShown,
            let homeView = homePopover.contentViewController?.view
        else {
            return
        }

        dashboardPopover.performClose(nil)
        dailyDetailsPopover.performClose(nil)
        presentationState.isDashboardShown = false

        // Anchor settings to the left edge of the home popover. This makes it
        // feel like a separate nearby screen instead of one larger shared view.
        settingsPopover.show(
            relativeTo: homeView.bounds,
            of: homeView,
            preferredEdge: .minX
        )
        presentationState.isSettingsShown = true
    }

    @objc private func toggleDashboardPopover() {
        if dashboardPopover.isShown {
            dashboardPopover.performClose(nil)
            settingsPopover.performClose(nil)
            dailyDetailsPopover.performClose(nil)
            presentationState.isDashboardShown = false
            presentationState.isSettingsShown = false
            return
        }

        guard homePopover.isShown,
            let homeView = homePopover.contentViewController?.view
        else {
            return
        }

        settingsPopover.performClose(nil)
        dailyDetailsPopover.performClose(nil)
        presentationState.isSettingsShown = false

        let positioningRect = homeView.bounds.offsetBy(dx: -180, dy: 0)

        dashboardPopover.show(
            relativeTo: positioningRect,
            of: homeView,
            preferredEdge: .minX
        )
        presentationState.isDashboardShown = true
        presentationState.dashboardAnimationToken = UUID()
    }

    private func showStatusItemMenu() {
        guard let button = statusItem?.button else {
            return
        }

        closeOpenSurfaces()

        showQuitMenuPanel(below: button)
    }

    private func showQuitMenuPanel(below button: NSStatusBarButton) {
        guard let reminderTimer else {
            return
        }

        let panelSize = NSSize(width: 120, height: 68)
        let buttonRectInScreen = button.window?.convertToScreen(button.frame) ?? .zero
        let panelOrigin = NSPoint(
            x: buttonRectInScreen.midX - panelSize.width / 2,
            y: buttonRectInScreen.minY - panelSize.height - 4
        )

        quitMenuPanel?.close()

        let panel = NSPanel(
            contentRect: NSRect(origin: panelOrigin, size: panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.backgroundColor = NSColor.clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .transient]

        let hostingView = NSHostingView(
            rootView: StatusQuitMenuView(
                reminderTimer: reminderTimer,
                onPauseClicked: { [weak self] in
                    self?.reminderTimer?.togglePause()
                    self?.quitMenuPanel?.close()
                    self?.quitMenuPanel = nil
                },
                onQuitClicked: { [weak self] in
                    self?.quitApp()
                }
            )
        )
        hostingView.frame = NSRect(origin: .zero, size: panelSize)
        hostingView.wantsLayer = true
        hostingView.layer?.cornerRadius = 8
        hostingView.layer?.masksToBounds = true
        panel.contentView = hostingView
        panel.orderFrontRegardless()

        // A borderless panel gives the right-click menu the flat rectangle shape
        // of a menu-bar utility dropdown instead of NSPopover's arrowed bubble.
        quitMenuPanel = panel
    }

    @objc private func quitApp() {
        closeOpenSurfaces()
        NSApp.terminate(nil)
    }

    private func showDailyDetails(for date: Date) {
        guard homePopover.isShown,
            let homeView = homePopover.contentViewController?.view
        else {
            return
        }

        // Updating observable state keeps the existing popover window and hosting
        // controller in place, so changing dates cannot trigger a resize flash.
        dailyDetailsSelection.selectedDate = date
        dailyDetailsPopover.contentSize = compactPopoverSize

        if dailyDetailsPopover.isShown {
            return
        }

        dailyDetailsPopover.show(
            relativeTo: homeView.bounds,
            of: homeView,
            preferredEdge: .minY
        )
    }

    private func showReminderBurst(for item: ReminderItem) {
        guard let button = statusItem?.button else {
            return
        }

        let panelSize = NSSize(
            width: ReminderBurstView.displaySize.width,
            height: ReminderBurstView.displaySize.height
        )
        let screenFrame =
            button.window?.screen?.frame ?? NSScreen.main?.frame ?? .zero
        let topRightMargin: CGFloat = 4
        let panelOrigin = NSPoint(
            // Use the full screen frame, not visibleFrame, so the notification
            // starts at the very top and can cover the menu bar date/time area.
            x: screenFrame.maxX - panelSize.width - topRightMargin,
            y: screenFrame.maxY - panelSize.height
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

        let hostingView = NSHostingView(rootView: ReminderBurstView(title: item.title))
        hostingView.frame = NSRect(origin: .zero, size: panelSize)
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentView = hostingView
        panel.orderFrontRegardless()

        reminderBurstPanel = panel

        DispatchQueue.main.asyncAfter(deadline: .now() + ReminderBurstView.animationDuration) {
            [weak self] in
            self?.reminderBurstPanel?.close()
            self?.reminderBurstPanel = nil
        }
    }

    private func updateStatusItemBadge() {
        statusItem?.button?.image = StatusItemBadge.image(isShowingDot: isShowingReminderDot)
        statusItem?.button?.toolTip = isShowingReminderDot ? "Reminder due" : nil
    }

    private func installOutsideClickMonitors() {
        let clickEvents: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]

        // Local events cover clicks delivered to this app, including the status
        // item and any popover windows. Keep those clicks alive, but collapse
        // open surfaces when the click lands outside the known app views.
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: clickEvents) {
            [weak self] event in
            guard let self else { return event }

            if !self.isEventInsideAppSurface(event) {
                self.closeOpenSurfaces()
            }

            return event
        }

        // Global events cover clicks in other apps. Semitransient popovers are
        // useful for Dashboard + Daily Details, but they need this explicit
        // outside-click path to dismiss as one group.
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: clickEvents) {
            [weak self] _ in
            self?.closeOpenSurfaces()
        }
    }

    private func removeOutsideClickMonitors() {
        if let localMouseMonitor {
            NSEvent.removeMonitor(localMouseMonitor)
            self.localMouseMonitor = nil
        }

        if let globalMouseMonitor {
            NSEvent.removeMonitor(globalMouseMonitor)
            self.globalMouseMonitor = nil
        }
    }

    private func isEventInsideAppSurface(_ event: NSEvent) -> Bool {
        let appSurfaceWindows = [
            statusItem?.button?.window,
            homePopover.contentViewController?.view.window,
            settingsPopover.contentViewController?.view.window,
            dashboardPopover.contentViewController?.view.window,
            dailyDetailsPopover.contentViewController?.view.window,
            quitMenuPanel,
            reminderBurstPanel
        ]

        return appSurfaceWindows.contains { window in
            guard let window else { return false }
            return event.window === window
        }
    }

    private func closeOpenSurfaces() {
        settingsPopover.performClose(nil)
        dashboardPopover.performClose(nil)
        dailyDetailsPopover.performClose(nil)
        quitMenuPanel?.close()
        quitMenuPanel = nil
        homePopover.performClose(nil)
        reminderBurstPanel?.close()
        reminderBurstPanel = nil
        presentationState.isSettingsShown = false
        presentationState.isDashboardShown = false
    }
}

private struct StatusQuitMenuView: View {
    @ObservedObject var reminderTimer: ReminderTimer
    let onPauseClicked: () -> Void
    let onQuitClicked: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            StatusMenuRow(
                title: reminderTimer.isPaused ? "Resume" : "Pause",
                action: onPauseClicked
            )

            Divider()
                // Keep the menu separation subtle so it reads like a native
                // utility dropdown divider instead of another selected row.
                .background(AppColors.controlBackground.opacity(0.55))
                .padding(.horizontal, 8)

            StatusMenuRow(
                title: "Quit",
                action: onQuitClicked
            )
        }
        .frame(width: 120, height: 68)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .background(AppColors.panelBackground.opacity(0.8))
        .preferredColorScheme(.light)
    }
}

private struct StatusMenuRow: View {
    let title: String
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Text(title)
                // Use the native Apple menu font for this flat utility menu,
                // unlike the app popovers that intentionally use Tabular.
                .font(.system(size: NSFont.menuFont(ofSize: 0).pointSize))
                .foregroundStyle(isHovering ? Color.white : AppColors.primaryText)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .background(isHovering ? Color.accentColor.opacity(0.8) : Color.clear)
        .frame(width: 120, height: 34)
    }
}

final class PopoverPresentationState: ObservableObject {
    // SwiftUI uses these values only for button styling; AppDelegate remains the
    // source of truth for actual popover placement and dismissal.
    @Published var isSettingsShown = false
    @Published var isDashboardShown = false
    @Published var dashboardAnimationToken = UUID()
}

private final class DailyDetailsSelection: ObservableObject {
    @Published var selectedDate = Date()
}

private struct DailyDetailsContainerView: View {
    @ObservedObject var achievementStore: AchievementStore
    @ObservedObject var selection: DailyDetailsSelection
    let size: NSSize

    var body: some View {
        DailyDetailsView(
            achievementStore: achievementStore,
            selectedDate: selection.selectedDate
        )
        // Match the popover's AppKit contentSize so SwiftUI never asks for a
        // larger host view while the user clicks between reward dates.
        .frame(width: size.width, height: size.height)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()

app.delegate = delegate

// Keep Tide Stamp out of the Dock because it is meant to live in the menu bar.
app.setActivationPolicy(.accessory)
app.run()
