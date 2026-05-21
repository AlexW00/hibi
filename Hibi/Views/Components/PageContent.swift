import SwiftUI

/// The visible content of one paper page — used by the Day tab's tear stack
/// and by the Today's Page widget. Pure presentation. All preference values
/// (`useSimpleFont`, `timeFormat`, `temperatureUnit`) are passed in by the
/// caller so the same view works in both processes (the main app reads them
/// from its `@AppStorage`; the widget reads them from `AppGroup.defaults`).
struct PageContent: View {
    let day: Int
    let month: Int
    let year: Int
    let isToday: Bool
    let weather: DayWeather?
    let locationName: String?
    let preview: Bool
    /// 1.0 = paper expanded (full corner widgets); 0.0 = collapsed via the
    /// schedule separator drag. Multiplies the opacity of the sunrise/sunset
    /// widgets, weather pill, Apple Weather attribution, and month/year
    /// sub-text — and collapses their reserved height so the central numeral
    /// block keeps its breathing room as the card shrinks. The weekday, day
    /// number, and today underline are not faded.
    var chromeFade: Double = 1.0

    let useSimpleFont: Bool
    let timeFormat: TimeFormat
    let temperatureUnit: TemperatureUnit

    var body: some View {
        VStack(spacing: 0) {
            topRow
            Spacer(minLength: 0)
            numeralBlock
            Spacer(minLength: 0)
            bottomRow
        }
        .padding(.horizontal, 22)
        .padding(.top, 34)
        .padding(.bottom, 20)
    }

    private var topRow: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Image(systemName: "sunrise")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                Text(weather?.sunrise.map { timeFormat.string(from: $0) } ?? "")
                    .font(.system(size: 9.5, design: .monospaced))
                    .tracking(0.6)
                    .foregroundStyle(.secondary)
            }
            .opacity(weather?.sunrise == nil ? 0 : chromeFade)
            Spacer()
            Text(DayNames.full[SampleData.weekday(year: year, month: month, day: day)])
                .font(.appSerif(size: 19, italic: true, simple: useSimpleFont))
                .foregroundStyle(.primary)
                .padding(.top, 2)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Image(systemName: "sunset")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                Text(weather?.sunset.map { timeFormat.string(from: $0) } ?? "")
                    .font(.system(size: 9.5, design: .monospaced))
                    .tracking(0.6)
                    .foregroundStyle(.secondary)
            }
            .opacity(weather?.sunset == nil ? 0 : chromeFade)
        }
        .frame(height: 44 * chromeFade + 24 * (1 - chromeFade))
        .clipped()
    }

    private var numeralBlock: some View {
        VStack(spacing: 2) {
            Text(verbatim: "\(day)")
                .font(.appSerif(size: 180, simple: useSimpleFont))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText(value: Double(day)))
                .frame(maxWidth: .infinity, alignment: .center)
                .overlay(alignment: .bottom) {
                    if isToday {
                        Rectangle()
                            .fill(.primary)
                            .frame(width: 80, height: 1.5)
                            .offset(y: -8)
                    }
                }
            Text(verbatim: "\(MonthNames.full[month - 1]) · \(String(year))")
                .font(.appSerif(size: 13, italic: true, simple: useSimpleFont))
                .foregroundStyle(.secondary)
                .padding(.top, 2)
                .frame(height: 18 * chromeFade)
                .opacity(chromeFade)
                .clipped()
        }
        .frame(maxWidth: .infinity)
    }

    private var bottomRow: some View {
        HStack(alignment: .bottom) {
            HStack(spacing: 8) {
                WeatherIcon(code: weather?.code ?? .sun, size: 22)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 0) {
                        Text(verbatim: "\(temperatureUnit.display(celsius: weather?.high ?? 0))°")
                            .font(.system(size: 15, weight: .medium))
                            .tracking(-0.3)
                        Text(verbatim: " / \(temperatureUnit.display(celsius: weather?.low ?? 0))°")
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                    }
                    .foregroundStyle(.primary)
                    MarqueeText(text: locationName ?? "")
                        .font(.system(size: 9.5))
                        .tracking(1.4)
                        .foregroundStyle(.secondary)
                }
            }
            .opacity(weather == nil ? 0 : 1)
            Spacer()
            AppleWeatherAttribution()
                .opacity(weather == nil ? 0 : 1)
        }
        .frame(height: 56 * chromeFade)
        .opacity(chromeFade)
        .clipped()
    }
}

/// Apple Weather attribution required by WeatherKit when weather data is
/// displayed (App Store Review Guideline 5.2.5). Renders the Apple Weather
/// trademark — the apple-logo glyph + the word "Weather" — and links to the
/// legal source page. Tappable; opens the attribution page in Safari.
struct AppleWeatherAttribution: View {
    var body: some View {
        Link(destination: URL(string: "https://weatherkit.apple.com/legal-attribution.html")!) {
            (Text(Image(systemName: "apple.logo")) + Text(verbatim: "\u{00a0}Weather"))
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(.secondary)
        }
        .accessibilityLabel(Text("Apple Weather"))
    }
}
