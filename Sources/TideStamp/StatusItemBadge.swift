import AppKit

enum StatusItemBadge {
    static func image(isShowingDot: Bool) -> NSImage {
        let label = "Tide"
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.menuBarFont(ofSize: 0),
            .foregroundColor: NSColor.labelColor
        ]
        let labelSize = label.size(withAttributes: labelAttributes)

        let imageHeight: CGFloat = 22
        let imageWidth = ceil(labelSize.width) + 4
        let image = NSImage(size: NSSize(width: imageWidth, height: imageHeight))

        image.lockFocus()

        let labelOrigin = CGPoint(
            x: 0,
            y: (imageHeight - labelSize.height) / 2
        )
        label.draw(at: labelOrigin, withAttributes: labelAttributes)

        if isShowingDot {
            // The dot intentionally overlaps the lower-right corner of "Tide"
            // so it reads like a badge attached to the menu bar item.
            let dotSize: CGFloat = 8
            let dotRect = CGRect(
                x: imageWidth - dotSize - 1,
                y: 2,
                width: dotSize,
                height: dotSize
            )

            NSColor.systemRed.setFill()
            NSBezierPath(ovalIn: dotRect).fill()
        }

        image.unlockFocus()
        image.isTemplate = false

        return image
    }
}
