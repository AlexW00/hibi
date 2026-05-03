import Foundation

struct WidgetEvent: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let startDate: Date?
    let endDate: Date?
    let tintHue: Double
    let tintSaturation: Double
    let tintBrightness: Double
    let location: String?
    let allDay: Bool
    let isRecurring: Bool
}
