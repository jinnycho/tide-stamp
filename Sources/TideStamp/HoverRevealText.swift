import AppKit
import SwiftUI

struct HoverRevealText: View {
    let text: String

    private var shouldRevealFullText: Bool {
        text.count > 16
    }

    var body: some View {
        Text(text)
            .font(AppFont.body)
            .lineLimit(1)
            .truncationMode(.tail)
            // List rows clip SwiftUI overlays, so the full title is shown by a
            // separate AppKit floating panel anchored to this text view.
            .background(HoverRevealAnchor(text: text, isEnabled: shouldRevealFullText))
            .help(text)
    }
}

private struct HoverRevealAnchor: NSViewRepresentable {
    let text: String
    let isEnabled: Bool

    func makeNSView(context: Context) -> HoverRevealAnchorView {
        HoverRevealAnchorView()
    }

    func updateNSView(_ nsView: HoverRevealAnchorView, context: Context) {
        nsView.text = text
        nsView.isRevealEnabled = isEnabled
    }
}

private final class HoverRevealAnchorView: NSView {
    var text = ""
    var isRevealEnabled = false

    private var trackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingArea {
            removeTrackingArea(trackingArea)
        }

        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        self.trackingArea = trackingArea
    }

    override func mouseEntered(with event: NSEvent) {
        guard isRevealEnabled else {
            return
        }

        HoverRevealPanel.shared.show(text: text, below: self)
    }

    override func mouseExited(with event: NSEvent) {
        HoverRevealPanel.shared.hide()
    }
}

private final class HoverRevealPanel {
    static let shared = HoverRevealPanel()

    private var panel: NSPanel?
    private let panelWidth: CGFloat = 220

    func show(text: String, below anchorView: NSView) {
        guard
            let window = anchorView.window,
            let screenFrame = window.screen?.visibleFrame
        else {
            return
        }

        let anchorRect = window.convertToScreen(anchorView.convert(anchorView.bounds, to: nil))
        let contentView = NSHostingView(rootView: HoverRevealBubble(text: text, width: panelWidth))
        let fittingSize = contentView.fittingSize
        let panelSize = NSSize(width: panelWidth, height: fittingSize.height)

        // Clamp the floating rectangle to the visible screen so long text stays
        // readable near the right or bottom edge of the menu-bar popover.
        let x = min(
            max(anchorRect.minX, screenFrame.minX + 8),
            screenFrame.maxX - panelSize.width - 8
        )
        let preferredY = anchorRect.minY - panelSize.height - 4
        let y =
            preferredY >= screenFrame.minY + 8
            ? preferredY
            : anchorRect.maxY + 4

        panel?.close()

        let panel = NSPanel(
            contentRect: NSRect(origin: NSPoint(x: x, y: y), size: panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.level = .floating
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .transient]
        panel.contentView = contentView
        panel.orderFrontRegardless()

        self.panel = panel
    }

    func hide() {
        panel?.close()
        panel = nil
    }
}

private struct HoverRevealBubble: View {
    let text: String
    let width: CGFloat

    var body: some View {
        Text(text)
            .font(AppFont.body)
            .foregroundStyle(AppColors.primaryText)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(width: width, alignment: .leading)
            .background(AppColors.panelBackground)
            .clipShape(RoundedRectangle(cornerRadius: 5))
    }
}
