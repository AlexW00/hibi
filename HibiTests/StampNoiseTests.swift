import Foundation
import Testing
@testable import Hibi

@Suite("StampNoise codec + index contract")
struct StampNoiseTests {

    @Test func defaultValuesCountMatchesParamCount() {
        #expect(StampNoise.defaultValues.count == StampNoise.Param.allCases.count)
    }

    @Test func countMatchesParamAllCases() {
        #expect(StampNoise.count == StampNoise.Param.allCases.count)
    }

    @Test func encodeDecodeRoundTrips() {
        let values = StampNoise.defaultValues
        let encoded = StampNoise.encode(values)
        let decoded = StampNoise.decode(encoded)
        #expect(decoded.count == values.count)
        for (a, b) in zip(values, decoded) {
            #expect(abs(a - b) < 1e-5)
        }
    }

    @Test func decodeWrongLengthFallsBackToDefaults() {
        let tooShort = "1.0,2.0,3.0"
        let decoded = StampNoise.decode(tooShort)
        #expect(decoded == StampNoise.defaultValues)
    }

    @Test func decodeEmptyStringFallsBackToDefaults() {
        let decoded = StampNoise.decode("")
        #expect(decoded == StampNoise.defaultValues)
    }

    @Test func decodeGarbageFallsBackToDefaults() {
        let decoded = StampNoise.decode("not,a,valid,float,array")
        #expect(decoded == StampNoise.defaultValues)
    }

    @Test func defaultValuesWithinRanges() {
        for param in StampNoise.Param.allCases {
            let value = StampNoise.defaultValues[param.rawValue]
            #expect(
                param.range.contains(value),
                "Param \(param.label) value \(value) outside range \(param.range)"
            )
        }
    }

    @Test func paramRawValuesAreContiguous() {
        let rawValues = StampNoise.Param.allCases.map(\.rawValue)
        for (i, raw) in rawValues.enumerated() {
            #expect(raw == i, "Param index gap at \(i): raw=\(raw)")
        }
    }

    @Test func defaultRawEncodesDefaults() {
        let decoded = StampNoise.decode(StampNoise.defaultRaw)
        #expect(decoded == StampNoise.defaultValues)
    }
}
