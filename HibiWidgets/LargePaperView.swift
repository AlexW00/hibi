import SwiftUI

/// The full expanded-paper composition for the `.systemLarge` widget.
/// Reuses `PageContent` from the main app and adds binding holes +
/// perforation chrome.
struct LargePaperView: View {
    let entry: TodaysPageEntry

    @AppStorage("useSimpleFont", store: AppGroup.defaults) private var useSimpleFont: Bool = false
    @AppStorage(TimeFormat.defaultsKey, store: AppGroup.defaults) private var timeFormatRaw: String = TimeFormat.system.rawValue
    @AppStorage(TemperatureUnit.defaultsKey, store: AppGroup.defaults) private var temperatureUnitRaw: String = TemperatureUnit.system.rawValue

    private var timeFormat: TimeFormat {
        TimeFormat(rawValue: timeFormatRaw) ?? .system
    }
    private var temperatureUnit: TemperatureUnit {
        TemperatureUnit(rawValue: temperatureUnitRaw) ?? .system
    }

    private var weather: DayWeather? {
        guard let s = entry.snapshot else { return nil }
        return DayWeather(
            high: s.high, low: s.low, code: s.code,
            sunrise: s.sunrise, sunset: s.sunset
        )
    }

    private var showsStaleHint: Bool {
        entry.snapshot == nil && (entry.daysSinceCapture ?? 0) >= 3
    }

    var body: some View {
        ZStack(alignment: .top) {
            BindingHoles()

            PageContent(
                day: entry.day,
                month: entry.month,
                year: entry.year,
                isToday: true,
                weather: weather,
                locationName: entry.snapshot?.locationName,
                preview: false,
                chromeFade: 1.0,
                useSimpleFont: useSimpleFont,
                timeFormat: timeFormat,
                temperatureUnit: temperatureUnit
            )
            .overlay(alignment: .bottom) {
                if showsStaleHint {
                    // Replaces the weather pill row when the cache is too old.
                    Text(String(localized: "Open Hibi to update"))
                        .font(.system(size: 11, weight: .regular).italic())
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 28)
                }
            }

            VStack {
                Spacer()
                PerforationEdge()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(largeAccessibilityLabel))
    }

    private var largeAccessibilityLabel: String {
        let weekday = DayNames.full[SampleData.weekday(year: entry.year, month: entry.month, day: entry.day)]
        let monthName = MonthNames.full[entry.month - 1]
        if let w = weather {
            return "\(weekday), \(monthName) \(entry.day). High \(temperatureUnit.display(celsius: w.high)) degrees, low \(temperatureUnit.display(celsius: w.low)) degrees."
        }
        return "\(weekday), \(monthName) \(entry.day)."
    }
}
