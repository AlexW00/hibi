import SwiftUI
import CoreText

@main
struct kalenderApp: App {
    init() {
        Self.registerFonts()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    private static func registerFonts() {
        let names = ["InstrumentSerif-Regular", "InstrumentSerif-Italic"]
        for name in names {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else {
                continue
            }
            var error: Unmanaged<CFError>?
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        }
    }
}
