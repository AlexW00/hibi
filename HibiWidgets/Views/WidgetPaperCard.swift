import SwiftUI

struct WidgetPaperCard: View {
    let day: Int
    let month: Int
    let year: Int
    let dayName: String
    let monthName: String
    let isToday: Bool
    let useSimpleFont: Bool
    let weatherHigh: Double?
    let weatherLow: Double?
    let weatherCode: String?
    let sunrise: Date?
    let sunset: Date?
    let locationName: String?
    let timeFormatRaw: String

    private let cornerRadius: CGFloat = 18

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(PaperTints.card1)
            .overlay {
                cardContent
            }
            .overlay(alignment: .top) {
                bindingHoles
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }

    private var cardContent: some View {
        VStack(spacing: 0) {
            topRow
            Spacer(minLength: 0)
            numeralBlock
            Spacer(minLength: 0)
            bottomRow
        }
        .padding(.horizontal, 14)
        .padding(.top, 24)
        .padding(.bottom, 12)
    }

    private var topRow: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 1) {
                Image(systemName: "sunrise")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text(sunrise.map { formatTime($0) } ?? "")
                    .font(.system(size: 8, design: .monospaced))
                    .tracking(0.4)
                    .foregroundStyle(.secondary)
            }
            .opacity(sunrise == nil ? 0 : 1)
            Spacer()
            Text(dayName)
                .font(.appSerif(size: 14, italic: true, simple: useSimpleFont))
                .foregroundStyle(.primary)
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Image(systemName: "sunset")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text(sunset.map { formatTime($0) } ?? "")
                    .font(.system(size: 8, design: .monospaced))
                    .tracking(0.4)
                    .foregroundStyle(.secondary)
            }
            .opacity(sunset == nil ? 0 : 1)
        }
    }

    private var numeralBlock: some View {
        VStack(spacing: 2) {
            Text(verbatim: "\(day)")
                .font(.appSerif(size: 90, simple: useSimpleFont))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(maxWidth: .infinity, alignment: .center)
                .overlay(alignment: .bottom) {
                    if isToday {
                        Rectangle()
                            .fill(.primary)
                            .frame(width: 50, height: 1.5)
                            .offset(y: -4)
                    }
                }
            Text(verbatim: "\(monthName) · \(String(year))")
                .font(.appSerif(size: 11, italic: true, simple: useSimpleFont))
                .foregroundStyle(.secondary)
        }
    }

    private var bottomRow: some View {
        HStack(alignment: .bottom) {
            HStack(spacing: 5) {
                Image(systemName: weatherSFSymbol)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                if let high = weatherHigh, let low = weatherLow {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 0) {
                            Text(verbatim: "\(Int(high.rounded()))°")
                                .font(.system(size: 11, weight: .medium))
                            Text(verbatim: " / \(Int(low.rounded()))°")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        .foregroundStyle(.primary)
                        if let loc = locationName {
                            Text(loc)
                                .font(.system(size: 8))
                                .tracking(1.0)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
            .opacity(weatherHigh == nil ? 0 : 1)
            Spacer()
        }
    }

    private var weatherSFSymbol: String {
        switch weatherCode {
        case "sun":    return "sun.max"
        case "pcloud": return "cloud.sun"
        case "cloud":  return "cloud"
        case "rain":   return "cloud.rain"
        case "wind":   return "wind"
        case "storm":  return "cloud.bolt.rain"
        default:       return "sun.max"
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        if timeFormatRaw == "h24" {
            formatter.dateFormat = "HH:mm"
        } else if timeFormatRaw == "h12" {
            formatter.dateFormat = "h:mm a"
        } else {
            formatter.timeStyle = .short
        }
        return formatter.string(from: date)
    }

    private var bindingHoles: some View {
        HStack(spacing: 60) {
            Circle()
                .fill(PaperTints.bindingHole)
                .frame(width: 8, height: 8)
                .overlay(Circle().strokeBorder(.black.opacity(0.1), lineWidth: 0.5))
            Circle()
                .fill(PaperTints.bindingHole)
                .frame(width: 8, height: 8)
                .overlay(Circle().strokeBorder(.black.opacity(0.1), lineWidth: 0.5))
        }
        .padding(.top, 8)
    }
}
