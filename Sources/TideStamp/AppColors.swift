import SwiftUI

enum AppColors {
    // Fixed palette requested for the menu popovers. These colors intentionally
    // avoid system materials so macOS light/dark appearance does not change them.
    static let dashboardBackground = Color.white
    static let panelBackground = Color(hex: 0xECEEF0)
    static let controlBackground = Color(hex: 0xDDE1E5)
    static let selectedControlBackground = Color(hex: 0xCCD4DC)
    static let primaryText = Color(hex: 0x202428)
    static let secondaryText = Color(hex: 0x68717A)
}

private extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0
        )
    }
}

struct FixedGrayButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.body)
            .foregroundStyle(AppColors.primaryText)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            // Keep app buttons slightly darker than the fixed panel background
            // and make press feedback deterministic across system appearances.
            .background {
                RoundedRectangle(cornerRadius: 5)
                    .fill(
                        configuration.isPressed
                            ? AppColors.selectedControlBackground
                            : AppColors.controlBackground
                    )
            }
    }
}

struct CompactIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.body)
            .foregroundStyle(AppColors.primaryText)
            .frame(width: 22, height: 22)
            // Ticking rows need a compact icon control; the regular grey button
            // style is intentionally padded for text buttons and makes rows tall.
            .background {
                RoundedRectangle(cornerRadius: 5)
                    .fill(
                        configuration.isPressed
                            ? AppColors.selectedControlBackground
                            : AppColors.controlBackground
                    )
            }
    }
}
