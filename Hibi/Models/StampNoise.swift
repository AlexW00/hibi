import Foundation

/// Procedural stamp-ink noise configuration.
///
/// The parameters are packed into a flat `[Float]` and handed to the
/// `stampEffect` Metal shader as a single `.floatArray` argument. The index
/// order here MUST stay in sync with the `P_*` constants in
/// `Hibi/Shaders/StampShader.metal`.
///
/// Noise mechanisms are role-separated (see the deep-research notes):
///   • supply  — low-frequency simplex field: macro ink density / pressure
///   • chips   — Worley cells: larger dry voids
///   • rough   — high-frequency boundary jaggedness
///   • edge    — SDF-driven rim darkening (squeegee) + outward capillary bleed
enum StampNoise {
    enum Param: Int, CaseIterable, Identifiable {
        case masterStrength = 0
        case supplyScale
        case supplyStrength
        case supplyErode
        case chipStrength
        case chipScale
        case edgeRoughness
        case edgeRoughScale
        case rimWidth
        case rimDarkness
        case bleedWidth
        case bleedStrength
        // Surface — independent of master (not noise).
        case specStrength
        case specFocus
        case bumpStrength

        var id: Int { rawValue }

        enum Group { case noise, surface }

        var group: Group {
            switch self {
            case .specStrength, .specFocus, .bumpStrength: .surface
            default: .noise
            }
        }

        var label: String {
            switch self {
            case .masterStrength:  "Master strength"
            case .supplyScale:     "Supply scale"
            case .supplyStrength:  "Supply strength"
            case .supplyErode:     "Supply erode (pt)"
            case .chipStrength:    "Chip voids"
            case .chipScale:       "Chip scale"
            case .edgeRoughness:   "Edge roughness (pt)"
            case .edgeRoughScale:  "Edge rough scale"
            case .rimWidth:        "Rim width (pt)"
            case .rimDarkness:     "Rim darkness"
            case .bleedWidth:      "Bleed width (pt)"
            case .bleedStrength:   "Bleed strength"
            case .specStrength:    "Specular strength"
            case .specFocus:       "Specular focus"
            case .bumpStrength:    "Depth strength"
            }
        }

        var detail: String {
            switch self {
            case .masterStrength:  "Overall noise amount. 0 = clean stamp."
            case .supplyScale:     "Size of the macro ink-density patches."
            case .supplyStrength:  "How much ink darkness varies across the stamp."
            case .supplyErode:     "How far low-ink areas eat inward from the edge."
            case .chipStrength:    "Amount of larger dry voids."
            case .chipScale:       "Void size — higher is smaller voids."
            case .edgeRoughness:   "How jagged the outline breaks up."
            case .edgeRoughScale:  "Frequency of the outline jaggedness."
            case .rimWidth:        "Width of the darker pressed edge (squeegee)."
            case .rimDarkness:     "How dark the pressed edge gets."
            case .bleedWidth:      "How far ink feathers outside the edge."
            case .bleedStrength:   "Amount of outward ink feathering."
            case .specStrength:    "Brightness of the tilt-driven highlight."
            case .specFocus:       "Higher = tighter, smaller highlight."
            case .bumpStrength:    "Strength of the embossed depth lighting."
            }
        }

        var range: ClosedRange<Float> {
            switch self {
            case .masterStrength:  0...1
            case .supplyScale:     0.5...8
            case .supplyStrength:  0...1
            case .supplyErode:     0...10
            case .chipStrength:    0...1
            case .chipScale:       4...40
            case .edgeRoughness:   0...8
            case .edgeRoughScale:  10...160
            case .rimWidth:        0...10
            case .rimDarkness:     0...1
            case .bleedWidth:      0...10
            case .bleedStrength:   0...1
            case .specStrength:    0...1
            case .specFocus:       2...24
            case .bumpStrength:    0...2
            }
        }
    }

    static let count = Param.allCases.count

    /// The single tuned preset baked into release builds. Values follow
    /// `Param.allCases` order:
    /// master, supplyScale, supplyStrength, supplyErode,
    /// chipStrength, chipScale, edgeRoughness, edgeRoughScale,
    /// rimWidth, rimDarkness, bleedWidth, bleedStrength,
    /// specStrength, specFocus, bumpStrength
    static let defaultValues: [Float] =
        [0.55, 2.24, 0.47, 2.04, 0.28, 13.31, 1.50, 75.27, 4.29, 0.60, 3.55, 0.16,
         0.84, 17.0, 1.7]

    // MARK: Persistence (DEBUG tuning only)

    static let valuesKey = "stampNoiseValues"
    static let presetKey = "stampNoisePreset"
    static let defaultPresetID = "default"
    /// Sentinel preset id used when the user has hand-edited a slider.
    static let customPresetID = "custom"

    static func encode(_ values: [Float]) -> String {
        values.map { String($0) }.joined(separator: ",")
    }

    static func decode(_ raw: String) -> [Float] {
        let parts = raw.split(separator: ",").compactMap { Float($0) }
        guard parts.count == count else { return defaultValues }
        return parts
    }

    static var defaultRaw: String { encode(defaultValues) }
}
