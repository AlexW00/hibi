import SwiftUI
import CoreText

@main
struct HibiApp: App {
    init() {
        Self.registerFonts()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    private static func registerFonts() {
        let fonts: [(name: String, ext: String)] = [
            ("InstrumentSerif-Regular", "ttf"),
            ("InstrumentSerif-Italic", "ttf"),
            ("NotoSerifJP-Regular", "otf"),
        ]
        for font in fonts {
            guard let url = Bundle.main.url(forResource: font.name, withExtension: font.ext) else {
                continue
            }
            var error: Unmanaged<CFError>?
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        }
    }
}
