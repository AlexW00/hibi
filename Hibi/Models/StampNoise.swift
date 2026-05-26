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
///   • mottle  — mid-frequency fBm: interior texture
///   • dropout — blue-noise-style dither: sparse missing ink, clustered in
///               low-supply regions
///   • chips   — Worley cells: larger dry voids
///   • edge    — SDF-driven rim darkening (squeegee) + outward capillary bleed
///   • rough   — high-frequency boundary jaggedness
enum StampNoise {
    enum Param: Int, CaseIterable, Identifiable {
        case masterStrength = 0
        case supplyScale
        case supplyStrength
        case supplyErode
        case mottleScale
        case mottleStrength
        case dropoutStrength
        case dropoutScale
        case chipStrength
        case chipScale
        case edgeRoughness
        case edgeRoughScale
        case rimWidth
        case rimDarkness
        case bleedWidth
        case bleedStrength

        var id: Int { rawValue }

        var label: String {
            switch self {
            case .masterStrength:  "Master strength"
            case .supplyScale:     "Supply scale"
            case .supplyStrength:  "Supply strength"
            case .supplyErode:     "Supply erode (pt)"
            case .mottleScale:     "Mottle scale"
            case .mottleStrength:  "Mottle strength"
            case .dropoutStrength: "Dropout amount"
            case .dropoutScale:    "Dropout grain"
            case .chipStrength:    "Chip voids"
            case .chipScale:       "Chip scale"
            case .edgeRoughness:   "Edge roughness (pt)"
            case .edgeRoughScale:  "Edge rough scale"
            case .rimWidth:        "Rim width (pt)"
            case .rimDarkness:     "Rim darkness"
            case .bleedWidth:      "Bleed width (pt)"
            case .bleedStrength:   "Bleed strength"
            }
        }

        var detail: String {
            switch self {
            case .masterStrength:  "Overall noise amount. 0 = clean stamp."
            case .supplyScale:     "Size of the macro ink-density patches."
            case .supplyStrength:  "How much ink darkness varies across the seal."
            case .supplyErode:     "How far low-ink areas eat inward from the edge."
            case .mottleScale:     "Frequency of the fine interior texture."
            case .mottleStrength:  "Amount of patchy interior darkening."
            case .dropoutStrength: "Density of tiny missing-ink specks."
            case .dropoutScale:    "Speck grain — higher is finer."
            case .chipStrength:    "Amount of larger dry voids."
            case .chipScale:       "Void size — higher is smaller voids."
            case .edgeRoughness:   "How jagged the outline breaks up."
            case .edgeRoughScale:  "Frequency of the outline jaggedness."
            case .rimWidth:        "Width of the darker pressed edge (squeegee)."
            case .rimDarkness:     "How dark the pressed edge gets."
            case .bleedWidth:      "How far ink feathers outside the edge."
            case .bleedStrength:   "Amount of outward ink feathering."
            }
        }

        var range: ClosedRange<Float> {
            switch self {
            case .masterStrength:  0...1
            case .supplyScale:     0.5...8
            case .supplyStrength:  0...1
            case .supplyErode:     0...10
            case .mottleScale:     2...24
            case .mottleStrength:  0...1
            case .dropoutStrength: 0...1
            case .dropoutScale:    0.5...6
            case .chipStrength:    0...1
            case .chipScale:       4...40
            case .edgeRoughness:   0...8
            case .edgeRoughScale:  10...160
            case .rimWidth:        0...10
            case .rimDarkness:     0...1
            case .bleedWidth:      0...10
            case .bleedStrength:   0...1
            }
        }
    }

    static let count = Param.allCases.count

    enum Preset: String, CaseIterable, Identifiable {
        case clean, balanced, dry, wet

        var id: String { rawValue }

        var label: String {
            switch self {
            case .clean:    "Clean"
            case .balanced: "Balanced"
            case .dry:      "Dry"
            case .wet:      "Wet"
            }
        }

        // Values follow `Param.allCases` order. See StampShader.metal.
        // master, supplyScale, supplyStrength, supplyErode,
        // mottleScale, mottleStrength, dropoutStrength, dropoutScale,
        // chipStrength, chipScale, edgeRoughness, edgeRoughScale,
        // rimWidth, rimDarkness, bleedWidth, bleedStrength
        var values: [Float] {
            switch self {
            case .clean:
                [0.0, 2.5, 0.35, 3.0, 9.0, 0.20, 0.18, 3.0, 0.0, 18.0, 2.0, 80.0, 3.0, 0.35, 2.0, 0.25]
            case .balanced:
                [1.0, 2.5, 0.35, 3.0, 9.0, 0.20, 0.18, 3.0, 0.0, 18.0, 2.0, 80.0, 3.0, 0.35, 2.0, 0.25]
            case .dry:
                [1.0, 2.0, 0.55, 5.0, 11.0, 0.35, 0.50, 3.5, 0.45, 16.0, 4.5, 90.0, 2.0, 0.25, 0.5, 0.05]
            case .wet:
                [1.0, 2.2, 0.18, 1.5, 8.0, 0.10, 0.05, 3.0, 0.0, 18.0, 1.0, 60.0, 5.0, 0.50, 4.0, 0.50]
            }
        }
    }

    /// The preset baked into release builds.
    static let defaultPreset: Preset = .balanced
    static var defaultValues: [Float] { defaultPreset.values }

    // MARK: Persistence (DEBUG tuning only)

    static let valuesKey = "stampNoiseValues"
    static let presetKey = "stampNoisePreset"
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
