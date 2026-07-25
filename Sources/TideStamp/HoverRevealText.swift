import SwiftUI

struct HoverRevealText: View {
    let text: String
    @State private var isHovering = false

    private var shouldRevealFullText: Bool {
        text.count > 16
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(text)
                .font(AppFont.body)
                .lineLimit(1)
                .truncationMode(.tail)

            if isHovering && shouldRevealFullText {
                Text(text)
                    .font(AppFont.body)
                    .foregroundStyle(AppColors.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    // The expanded copy appears directly under the clipped row
                    // label so long reminders can be read without opening edit.
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColors.panelBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            }
        }
        // Keep the reveal visible while the pointer moves from the clipped
        // title down into the expanded full text.
        .onHover { isHovering = $0 }
        .help(text)
    }
}
