import Testing
import Foundation
@testable import Hibi

struct StylePayloadsTests {
    @Test func textPayloadRoundTrips() throws {
        var p = TextStylePayload()
        p.font = "InstrumentSerif"; p.bold = true; p.colorToken = 2
        let data = try p.encoded()
        let back = try TextStylePayload(data: data)
        #expect(back.font == "InstrumentSerif")
        #expect(back.bold == true)
        #expect(back.colorToken == 2)
        #expect(back.v == 1)
    }
    @Test func oldBlobMissingNewFieldsStillDecodes() throws {
        // Simulate a blob written by an older version (only v + font present).
        let old = Data(#"{"v":1,"font":"X"}"#.utf8)
        let p = try TextStylePayload(data: old)
        #expect(p.font == "X")
        #expect(p.bold == nil)         // new field defaults, no crash
        #expect(p.effect == nil)
    }
    @Test func emptyDataDecodesToDefault() {
        #expect((try? TextStylePayload(data: Data())) == nil) // callers treat nil/empty as default payload
    }
}
