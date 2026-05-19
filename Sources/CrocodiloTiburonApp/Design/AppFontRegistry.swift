import CoreText
import Foundation

enum AppFontRegistry {
    static func registerFonts() {
        registerFont(named: "Inter-Regular", extension: "ttf")
    }

    private static func registerFont(named name: String, extension fileExtension: String) {
        guard let url = Bundle.module.url(
            forResource: name,
            withExtension: fileExtension,
            subdirectory: "Fonts"
        ) else { return }

        var error: Unmanaged<CFError>?
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
    }
}
