import SwiftUI

struct ReminderBurstView: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(.red.opacity(0.18))
                .frame(width: 52, height: 52)

            Circle()
                .fill(.red)
                .frame(width: 24, height: 24)
        }
        .padding(8)
    }
}
