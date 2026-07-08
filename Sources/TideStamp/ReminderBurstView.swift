import AppKit
import SwiftUI

struct ReminderBurstView: View {
    private static let frameRate = 24.0
    private static let frameCount = 74
    private static let loopCount = 1
    static let displaySize: CGFloat = 136

    static let animationDuration = Double(frameCount * loopCount) / frameRate

    private static let frames: [NSImage] = (1...frameCount).compactMap { frameNumber in
        // Keep the animation driven by the numbered PNG sequence so the burst
        // stays lightweight and deterministic without adding a video player.
        let frameName = String(format: "frame_%02d", frameNumber)

        // SwiftPM flattens the processed Assets/cat1 PNGs into the resource bundle root.
        // Use the transparent frames only; frames 75...79 are currently opaque duplicates.
        guard let url = Bundle.module.url(
            forResource: frameName,
            withExtension: "png"
        ) else {
            return nil
        }

        return NSImage(contentsOf: url)
    }

    private let startDate = Date()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / Self.frameRate)) { timeline in
            let frameIndex = currentFrameIndex(at: timeline.date)

            if Self.frames.indices.contains(frameIndex) {
                Image(nsImage: Self.frames[frameIndex])
                    .resizable()
                    .scaledToFit()
                    .frame(width: Self.displaySize, height: Self.displaySize)
            }
        }
        .frame(width: Self.displaySize, height: Self.displaySize)
    }

    private func currentFrameIndex(at date: Date) -> Int {
        // Play the transparent cat1 sequence once. If the panel stays open a little
        // longer, hold on the final frame instead of wrapping forever.
        let elapsed = date.timeIntervalSince(startDate)
        let finalFrame = (Self.frameCount * Self.loopCount) - 1
        let animationFrame = min(Int(elapsed * Self.frameRate), finalFrame)

        return animationFrame % Self.frameCount
    }
}
