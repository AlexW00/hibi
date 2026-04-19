import CoreLocation
import Foundation
import MapKit
import Observation
import OSLog
import WeatherKit

@MainActor
@Observable
final class WeatherStore: NSObject {
    private(set) var authorizationStatus: CLAuthorizationStatus
    private(set) var locationName: String?

    private var weatherByDay: [DayKey: DayWeather] = [:]
    private var lastFetchLocation: CLLocation?
    private var lastFetchAt: Date?
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
        self.authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    // MARK: - Access

    func requestAccess() {
        guard authorizationStatus == .notDetermined else { return }
        manager.requestWhenInUseAuthorization()
    }

    // MARK: - Query

    func weather(year: Int, month: Int, day: Int) -> DayWeather? {
        weatherByDay[DayKey(year: year, month: month, day: day)]
    }

    // MARK: - Refresh

    /// Fetches a fresh location + weather if the cache is stale.
    /// Safe to call repeatedly — self-throttles.
    func refresh() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            return
        }
        if let last = lastFetchAt, Date().timeIntervalSince(last) < 30 * 60 {
            return
        }
        guard inFlight == nil else { return }
        manager.requestLocation()
    }

    private func performFetch(location: CLLocation) {
        inFlight?.cancel()
        inFlight = Task { [weak self] in
            guard let self else { return }
            await self.fetchAll(location: location)
            await MainActor.run { self.inFlight = nil }
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
        lastFetchAt = Date()

        guard let weather else { return }

        var byDay: [DayKey: DayWeather] = [:]
        for day in weather.dailyForecast {
            let comps = calendar.dateComponents([.year, .month, .day], from: day.date)
            guard let y = comps.year, let m = comps.month, let d = comps.day else { continue }
            let high = Int(day.highTemperature.converted(to: .celsius).value.rounded())
            let low = Int(day.lowTemperature.converted(to: .celsius).value.rounded())
            byDay[DayKey(year: y, month: m, day: d)] = DayWeather(
                high: high,
                low: low,
                code: Self.code(for: day.condition),
                sunrise: day.sun.sunrise,
                sunset: day.sun.sunset
            )
        }
        self.weatherByDay = byDay
    }

    // MARK: - Mapping

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
        let status = manager.authorizationStatus
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.authorizationStatus = status
            if status == .authorizedWhenInUse || status == .authorizedAlways {
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
            self?.log.error("Location fetch failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
