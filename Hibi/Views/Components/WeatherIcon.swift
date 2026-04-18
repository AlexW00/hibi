import SwiftUI

struct WeatherIcon: View {
    let code: WeatherCode
    var size: CGFloat = 22

    var body: some View {
        Image(systemName: code.sfSymbol)
            .font(.system(size: size, weight: .regular))
            .symbolRenderingMode(.monochrome)
    }
}
