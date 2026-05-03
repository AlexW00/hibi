import SwiftUI

enum AppFont {
    static let serifRegular = "InstrumentSerif-Regular"
    static let serifItalic  = "InstrumentSerif-Italic"
    static let serifJP = "NotoSerifJP-Regular"

    static var usesCJKSerif: Bool {
        guard let first = Locale.preferredLanguages.first else { return false }
        switch Locale(identifier: first).language.languageCode?.identifier {
        case "ja", "zh", "ko":
            return true
        default:
            return false
        }
    }
}

extension Font {
    static func appSerif(size: CGFloat, italic: Bool = false, simple: Bool) -> Font {
        if simple {
            let base = Font.system(size: size)
            return italic ? base.italic() : base
        }
        if AppFont.usesCJKSerif {
            let base = Font.custom(AppFont.serifJP, size: size)
            return italic ? base.italic() : base
        }
        return .custom(italic ? AppFont.serifItalic : AppFont.serifRegular, size: size)
    }
}
