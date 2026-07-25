import AppKit
import SwiftUI

struct ReminderBurstView: View {
    static let displaySize = NSSize(width: 216, height: 270)
    static let animationDuration = 5.5
    private static let feedCycleDuration = 0.50
    private static let feedCycleCount = 7
    private static let initialVisibleFraction: CGFloat = 0.10
    private static let feedAdvanceFraction: CGFloat = 0.15
    private static let feedBackstepFraction: CGFloat = 0.008
    private static let titleLineLength = 16
    private static let titleTopOffset: CGFloat = 134

    private static let notificationImage: NSImage? = {
        // SwiftPM flattens processed asset paths into the resource bundle root,
        // so notification_background.png is loaded by name even though the
        // source file lives in Assets/notification.
        guard
            let url = Bundle.module.url(
                forResource: "notification_background",
                withExtension: "png"
            )
        else {
            return nil
        }

        return NSImage(contentsOf: url)
    }()

    private let startDate = Date()
    let title: String

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            if let notificationImage = Self.notificationImage {
                let paperOffset = paperOffset(at: timeline.date)

                ZStack {
                    Image(nsImage: notificationImage)
                        .resizable()
                        .scaledToFit()

                    VStack(spacing: 0) {
                        Text(formattedTitle)
                            .font(AppFont.notificationTitle)
                            .foregroundStyle(Color.black)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.55)
                            // Keep the printed reminder comfortably inside the
                            // receipt image instead of touching the paper edges.
                            .padding(.horizontal, 22)

                        Spacer(minLength: 0)
                    }
                    // Anchor the first reminder line to the receipt body. Extra
                    // wrapped lines now flow downward instead of pushing the
                    // existing text upward as the title gets longer.
                    .padding(.top, Self.titleTopOffset)
                    .frame(
                        width: Self.displaySize.width,
                        height: Self.displaySize.height,
                        alignment: .top
                    )
                }
                .frame(width: Self.displaySize.width, height: Self.displaySize.height)
                // Move the paper itself behind a fixed clipping window. This
                // makes the receipt image and title travel downward together
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

    private var formattedTitle: String {
        let characters = Array(title)

        // Receipt reminders use a fixed character count per line so long task
        // names wrap predictably on the printed paper, independent of view width.
        return stride(from: 0, to: characters.count, by: Self.titleLineLength)
            .map { startIndex in
                let endIndex = min(startIndex + Self.titleLineLength, characters.count)
                return String(characters[startIndex..<endIndex])
            }
            .joined(separator: "\n")
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
            // Printer feed: push the paper down in a visible chunk, but ease
            // each chunk so the motion is less abrupt without becoming a slide.
            let progress = smoothstep(CGFloat(cycleProgress / 0.38))
            fraction = settledBase + (Self.feedAdvanceFraction * progress)
        case ..<0.56:
            // Mechanical slip: keep the receipt-printer character, just make
            // the backward motion subtle enough that it does not feel jumpy.
            let progress = smoothstep(CGFloat((cycleProgress - 0.38) / 0.18))
            fraction =
                settledBase + Self.feedAdvanceFraction
                - (Self.feedBackstepFraction * progress)
        default:
            // Brief hold: make each feed step readable instead of perfectly smooth.
            fraction = settledBase + settledCycleAdvance
        }

        return min(max(fraction, Self.initialVisibleFraction), 1)
    }

    private func smoothstep(_ progress: CGFloat) -> CGFloat {
        let clampedProgress = min(max(progress, 0), 1)
        return clampedProgress * clampedProgress * (3 - (2 * clampedProgress))
    }
}
