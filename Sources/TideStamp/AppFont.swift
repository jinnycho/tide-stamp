import AppKit
import CoreText
import SwiftUI

enum AppFont {
    private static let registeredFontResourceNames = [
        "Tabular-Light",
        "Tabular-Regular",
        "Tabular-Medium",
        "Tabular-Semibold"
    ]

    private static let regularFontName = "Tabular-Regular"
    private static let lightFontName = "Tabular-Light"
    private static let mediumFontName = "Tabular-Medium"
    private static let semiboldFontName = "Tabular-Semibold"

    // Register every bundled Tabular weight once at launch. SwiftPM copies these
    // files into Bundle.module, but macOS does not reliably expose package fonts
    // to Font.custom/NSFont until CoreText registers them for this process.
    static func registerBundledFonts() {
        registeredFontResourceNames.forEach {
            registerFont(resourceName: $0, fileExtension: "ttf")
        }
    }

    // Use explicit Tabular faces for the places that previously had explicit
    // system fonts. The root body font below covers inherited SwiftUI text.
    static var body: Font {
        Font.custom(regularFontName, size: NSFont.systemFontSize)
    }

    static var headline: Font {
        Font.custom(semiboldFontName, size: NSFont.systemFontSize)
    }

    static var notificationTitle: Font {
        // Match the receipt-style notification artwork with Tabular Light.
        // 13.2pt is 40% smaller than the previous 22pt display size.
        Font.custom(lightFontName, size: 13.2)
    }

    static var monthLabel: Font {
        Font.custom(mediumFontName, size: 8)
    }

    static var statusItem: NSFont {
        NSFont(name: semiboldFontName, size: NSFont.systemFontSize)
            ?? NSFont.menuBarFont(ofSize: 0)
    }

    private static func registerFont(resourceName: String, fileExtension: String) {
        guard let fontURL = Bundle.module.url(
            forResource: resourceName,
            withExtension: fileExtension
        ) else {
            assertionFailure("Missing bundled font: \(resourceName).\(fileExtension)")
            return
        }

        var registrationError: Unmanaged<CFError>?
        let didRegister = CTFontManagerRegisterFontsForURL(
            fontURL as CFURL,
            .process,
            &registrationError
        )

        if !didRegister, let registrationError {
            assertionFailure("Failed to register font: \(registrationError.takeRetainedValue())")
        }
    }
}
