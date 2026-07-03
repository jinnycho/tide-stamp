import AppKit
import SwiftUI

struct ReminderBurstView: View {
    private static let frameRate = 24.0
    private static let frameCount = 24
    private static let loopCount = 2

    static let animationDuration = Double(frameCount * loopCount) / frameRate

    private static let frames: [NSImage] = (1...frameCount).compactMap { frameNumber in
        // SwiftPM processes the PNGs from Assets/SimpleMove into the resource
        // bundle root, so look up frame_01.png through frame_24.png directly.
        let frameName = String(format: "frame_%02d", frameNumber)

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
                    .frame(width: 68, height: 68)
            }
        }
        .frame(width: 68, height: 68)
    }

    private func currentFrameIndex(at date: Date) -> Int {
        // Play frame_01...frame_24 twice. If the panel stays open a little
        // longer, hold on the final frame instead of wrapping forever.
        let elapsed = date.timeIntervalSince(startDate)
        let finalFrame = (Self.frameCount * Self.loopCount) - 1
        let animationFrame = min(Int(elapsed * Self.frameRate), finalFrame)

        return animationFrame % Self.frameCount
    }
}
