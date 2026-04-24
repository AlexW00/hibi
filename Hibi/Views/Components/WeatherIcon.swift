import SwiftUI

struct WeatherIcon: View {
    let code: WeatherCode
    var size: CGFloat = 22

    @AppStorage(IconStyle.defaultsKey) private var iconStyleRaw: String = IconStyle.standard.rawValue

    private var isKawaii: Bool {
        IconStyle(rawValue: iconStyleRaw) == .kawaii
    }

    var body: some View {
        if isKawaii, let asset = code.kawaiiAsset {
            Image(asset)
                .renderingMode(.original)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size * 2, height: size * 2)
        } else {
            Image(systemName: code.sfSymbol)
                .font(.system(size: size, weight: .regular))
                .symbolRenderingMode(.monochrome)
        }
    }
}
