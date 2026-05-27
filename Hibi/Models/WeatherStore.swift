import CoreLocation
import Foundation
import LocationPermission
import MapKit
import Observation
import OSLog
import PermissionsKit
import WeatherKit
import WidgetKit

@MainActor
@Observable
final class WeatherStore: NSObject {
    private(set) var hasLocationAccess: Bool
    private(set) var locationAccessDenied: Bool
    private(set) var locationName: String?

    private var weatherByDay: [DayKey: DayWeather] = [:]
    private var lastFetchLocation: CLLocation?
    private(set) var lastFetchAt: Date?
    private(set) var lastFailureAt: Date?
    private(set) var isLocationPending = false
    private var inFlight: Task<Void, Never>?

    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private let weatherService = WeatherService.shared
    @ObservationIgnored private let log = Logger(subsystem: "me.alexweichart.hibi", category: "weather")

    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.locale = .autoupdatingCurrent
        return c
    }()

    private struct DayKey: Hashable {
        let year: Int
        let month: Int
        let day: Int
    }

    override init() {
        let permission = Permission.location(access: .whenInUse)
        self.hasLocationAccess = permission.authorized
        self.locationAccessDenied = permission.denied
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    // MARK: - Access

    func requestAccess() async {
        let permission = Permission.location(access: .whenInUse)
        guard permission.notDetermined else { return }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            permission.request {
                continuation.resume()
            }
        }
        hasLocationAccess = permission.authorized
        locationAccessDenied = permission.denied
        if hasLocationAccess { refresh() }
    }

    /// Deep-link to Hibi's Settings page where the user can toggle location access.
    func openLocationSettings() {
        Permission.location(access: .whenInUse).openSettingPage()
    }

    // MARK: - Query

    func weather(year: Int, month: Int, day: Int) -> DayWeather? {
        weatherByDay[DayKey(year: year, month: month, day: day)]
    }

    // MARK: - Refresh

    /// Fetches a fresh location + weather if the cache is stale.
    /// Safe to call repeatedly — self-throttles.
    func refresh() {
        guard hasLocationAccess else { return }
        if let last = lastFetchAt, Date().timeIntervalSince(last) < 30 * 60 {
            return
        }
        if let fail = lastFailureAt, Date().timeIntervalSince(fail) < 5 * 60 {
            return
        }
        guard inFlight == nil else { return }
        guard !isLocationPending else { return }
        isLocationPending = true
        manager.requestLocation()
    }

    private func performFetch(location: CLLocation) {
        isLocationPending = false
        inFlight?.cancel()
        inFlight = Task { [weak self] in
            guard let self else { return }
            await self.fetchAll(location: location)
            guard !Task.isCancelled else { return }
            self.inFlight = nil
        }
    }

    private func fetchAll(location: CLLocation) async {
        async let weather: Weather? = {
            do {
                return try await weatherService.weather(for: location)
            } catch {
                log.error("WeatherKit fetch failed: \(error.localizedDescription, privacy: .public)")
                return nil
            }
        }()

        async let placeName: String? = {
            do {
                guard let request = MKReverseGeocodingRequest(location: location) else { return nil }
                let mapItems = try await request.mapItems
                return mapItems.first?.addressRepresentations?.cityName
            } catch {
                log.error("Reverse geocode failed: \(error.localizedDescription, privacy: .public)")
                return nil
            }
        }()

        let (weatherResult, nameResult) = await (weather, placeName)
        apply(weather: weatherResult, placeName: nameResult, location: location)
    }

    private func apply(weather: Weather?, placeName: String?, location: CLLocation) {
        if let placeName { self.locationName = placeName }
        lastFetchLocation = location

        guard let weather else { return }
        lastFetchAt = Date()
        lastFailureAt = nil

        var byDay: [DayKey: DayWeather] = [:]
        for day in weather.dailyForecast {
            let comps = calendar.dateComponents([.year, .month, .day], from: day.date)
            guard let y = comps.year, let m = comps.month, let d = comps.day else { continue }
            let high = day.highTemperature.converted(to: .celsius).value
            let low = day.lowTemperature.converted(to: .celsius).value
            byDay[DayKey(year: y, month: m, day: d)] = DayWeather(
                high: high,
                low: low,
                code: Self.code(for: day.condition),
                sunrise: day.sun.sunrise,
                sunset: day.sun.sunset
            )
        }
        self.weatherByDay = byDay

        // Persist today's forecast for the widget. "Today" is computed in
        // the store's own calendar to match the app's day boundary.
        let now = Date()
        let todayComps = self.calendar.dateComponents([.year, .month, .day], from: now)
        if let y = todayComps.year, let m = todayComps.month, let d = todayComps.day,
           let today = byDay[DayKey(year: y, month: m, day: d)] {
            writeWidgetSnapshot(today: today, year: y, month: m, day: d)
        }
    }

    // MARK: - Widget snapshot

    /// Persist today's forecast to the App Group so the Today's Page widget
    /// can render. Called from `apply(...)` after a successful fetch.
    /// No-op if the App Group capability hasn't been configured.
    private func writeWidgetSnapshot(today: DayWeather, year: Int, month: Int, day: Int) {
        let snapshot = WidgetWeatherSnapshot(
            year: year, month: month, day: day,
            high: today.high, low: today.low, code: today.code,
            sunrise: today.sunrise, sunset: today.sunset,
            locationName: self.locationName,
            capturedAt: Date()
        )
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        AppGroup.defaults?.set(data, forKey: AppGroup.Key.snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Mapping

    #if DEBUG
    func _test_setAccess(_ access: Bool) {
        hasLocationAccess = access
        locationAccessDenied = !access
    }

    func _test_simulateSuccessfulFetch() {
        isLocationPending = false
        lastFetchAt = Date()
        lastFailureAt = nil
    }

    func _test_simulateLocationFailure() {
        isLocationPending = false
        lastFailureAt = Date()
    }
    #endif

    private static func code(for condition: WeatherCondition) -> WeatherCode {
        switch condition {
        case .clear, .mostlyClear, .hot:
            return .sun
        case .partlyCloudy, .mostlyCloudy:
            return .pcloud
        case .cloudy, .foggy, .haze, .smoky:
            return .cloud
        case .drizzle, .freezingDrizzle, .freezingRain, .heavyRain, .rain, .isolatedThunderstorms, .sunShowers:
            return .rain
        case .breezy, .windy, .blowingDust, .tropicalStorm, .hurricane:
            return .wind
        case .thunderstorms, .strongStorms, .blizzard, .heavySnow, .hail:
            return .storm
        default:
            return .cloud
        }
    }
}

extension WeatherStore: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let permission = Permission.location(access: .whenInUse)
            self.hasLocationAccess = permission.authorized
            self.locationAccessDenied = permission.denied
            if self.hasLocationAccess {
                self.refresh()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor [weak self] in
            self?.performFetch(location: location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.log.error("Location fetch failed: \(error.localizedDescription, privacy: .public)")
            self.isLocationPending = false
            self.lastFailureAt = Date()
        }
    }
}
