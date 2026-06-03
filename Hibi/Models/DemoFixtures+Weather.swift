import Foundation

/// Demo weather for screenshots. Synthesized deterministically from the date so
/// every visible day in the Day / Week views shows a forecast (no empty weather
/// pill) without a live WeatherKit fetch — and so screenshots are identical run
/// to run. Only the city name is localized; temperatures and conditions are
/// shared across locales.
extension DemoFixtures {
    /// City shown in the Day-view masthead, per resolved demo language.
    static var demoCityName: String {
        switch resolvedLanguage {
        case .english:            return "San Francisco"
        case .german:             return "Berlin"
        case .japanese:           return "東京"
        case .korean:             return "서울"
        case .chineseSimplified:  return "上海"
        case .chineseTraditional: return "台北"
        }
    }

    /// A pleasant, deterministic spring forecast for any day. The demo anchor
    /// (April 18 — SampleData "today") is pinned to a clear, mild day so the
    /// hero Day screenshot always looks its best.
    static func demoWeather(year: Int, month: Int, day: Int) -> DayWeather {
        let sunrise = date(year, month, day, h: 6, min: 28)
        let sunset = date(year, month, day, h: 20, min: 12)

        if month == 4 && day == 18 {
            return DayWeather(high: 21, low: 12, code: .sun, sunrise: sunrise, sunset: sunset)
        }

        // Deterministic, varied-but-fair conditions.
        let codes: [WeatherCode] = [.sun, .pcloud, .sun, .cloud, .pcloud, .sun, .rain]
        let h = abs((year &* 73_856_093) ^ (month &* 19_349_663) ^ (day &* 83_492_791))
        let code = codes[h % codes.count]
        let high = Double(16 + (h % 8))      // 16–23 °C
        let low = high - Double(6 + (h % 4)) // 6–9 °C below the high
        return DayWeather(high: high, low: low, code: code, sunrise: sunrise, sunset: sunset)
    }
}
