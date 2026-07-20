import AppKit
import SwiftUI

struct ReminderBurstView: View {
    static let displaySize = NSSize(width: 216, height: 270)
    static let animationDuration = 5.5
    private static let feedCycleDuration = 0.50
    private static let feedCycleCount = 7
    private static let initialVisibleFraction: CGFloat = 0.10
    private static let feedAdvanceFraction: CGFloat = 0.15
    private static let feedBackstepFraction: CGFloat = 0.02

    private static let notificationImage: NSImage? = {
        // SwiftPM flattens processed asset paths into the resource bundle root,
        // so notification_background.png is loaded by name even though the
        // source file lives in Assets/notification.
        guard let url = Bundle.module.url(
            forResource: "notification_background",
            withExtension: "png"
        ) else {
            return nil
        }

        return NSImage(contentsOf: url)
    }()

    private let startDate = Date()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            if let notificationImage = Self.notificationImage {
                let paperOffset = paperOffset(at: timeline.date)

                Image(nsImage: notificationImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: Self.displaySize.width, height: Self.displaySize.height)
                    // Move the paper itself behind a fixed clipping window. This
                    // makes the receipt's bottom edge/black line travel downward
                    // as the leading edge, instead of appearing only at 100%.
                    .offset(y: paperOffset)
                    .frame(width: Self.displaySize.width, height: Self.displaySize.height)
                    .clipped()
            }
        }
        .frame(width: Self.displaySize.width, height: Self.displaySize.height)
        .clipped()
    }

    private func paperOffset(at date: Date) -> CGFloat {
        -Self.displaySize.height * (1 - printedFraction(at: date))
    }

    private func printedFraction(at date: Date) -> CGFloat {
        let elapsed = date.timeIntervalSince(startDate)
        let cycleIndex = min(Int(elapsed / Self.feedCycleDuration), Self.feedCycleCount)

        guard cycleIndex < Self.feedCycleCount else {
            return 1
        }

        let cycleElapsed = elapsed - (Double(cycleIndex) * Self.feedCycleDuration)
        let cycleProgress = cycleElapsed / Self.feedCycleDuration
        let settledCycleAdvance = Self.feedAdvanceFraction - Self.feedBackstepFraction
        let settledBase =
            Self.initialVisibleFraction + (CGFloat(cycleIndex) * settledCycleAdvance)

        let fraction: CGFloat

        switch cycleProgress {
        case ..<0.38:
            // Printer feed: push the paper down in a visible chunk.
            let progress = CGFloat(cycleProgress / 0.38)
            fraction = settledBase + (Self.feedAdvanceFraction * progress)
        case ..<0.56:
            // Mechanical slip: pull back slightly before the next feed.
            let progress = CGFloat((cycleProgress - 0.38) / 0.18)
            fraction =
                settledBase + Self.feedAdvanceFraction
                - (Self.feedBackstepFraction * progress)
        default:
            // Brief hold: make each feed step readable instead of perfectly smooth.
            fraction = settledBase + settledCycleAdvance
        }

        return min(max(fraction, Self.initialVisibleFraction), 1)
    }
}
