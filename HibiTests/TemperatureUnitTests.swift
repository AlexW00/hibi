import Foundation
import Testing
@testable import Hibi

@Suite("TemperatureUnit.display + .resolved")
struct TemperatureUnitTests {

    // MARK: - Celsius passthrough

    @Test(arguments: [
        (0.0, 0), (100.0, 100), (23.4, 23), (-40.0, -40), (36.6, 37),
    ])
    func celsiusPassthrough(celsius: Double, expected: Int) {
        #expect(TemperatureUnit.celsius.display(celsius: celsius) == expected)
    }

    // MARK: - Fahrenheit conversion

    @Test(arguments: [
        (0.0, 32),     // Freezing point
        (100.0, 212),  // Boiling point
        (23.4, 74),    // Documented rounding bug scenario
        (-40.0, -40),  // Crossover point
        (37.0, 99),    // Body temperature
    ])
    func fahrenheitConversion(celsius: Double, expected: Int) {
        #expect(TemperatureUnit.fahrenheit.display(celsius: celsius) == expected)
    }

    // MARK: - Resolved unit

    @Test func celsiusResolvesToCelsius() {
        #expect(TemperatureUnit.celsius.resolved == .celsius)
    }

    @Test func fahrenheitResolvesToFahrenheit() {
        #expect(TemperatureUnit.fahrenheit.resolved == .fahrenheit)
    }

    @Test func systemResolvesToSomething() {
        let resolved = TemperatureUnit.system.resolved
        #expect(resolved == .celsius || resolved == .fahrenheit)
    }
}
