import SwiftUI
import WidgetKit

struct EventsWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: EventsEntry

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                smallLayout
            default:
                mediumLayout
            }
        }
        .widgetURL(URL(string: "hibi://day?year=\(entry.year)&month=\(entry.month)&day=\(entry.day)"))
    }

    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 4) {
            header
            if entry.events.isEmpty {
                Spacer()
                emptyState
                Spacer()
            } else {
                ForEach(entry.events.prefix(3)) { event in
                    WidgetEventRow(event: event, timeFormatRaw: entry.timeFormatRaw)
                }
                if entry.events.count > 3 {
                    Text("+\(entry.events.count - 3) more")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(12)
    }

    private var mediumLayout: some View {
        VStack(alignment: .leading, spacing: 4) {
            header
            if entry.events.isEmpty {
                Spacer()
                emptyState
                Spacer()
            } else {
                ForEach(entry.events.prefix(4)) { event in
                    WidgetEventRow(event: event, timeFormatRaw: entry.timeFormatRaw)
                }
                if entry.events.count > 4 {
                    Text("+\(entry.events.count - 4) more")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(12)
    }

    private var header: some View {
        HStack(spacing: 4) {
            Text(entry.dayName)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(verbatim: "\(entry.day)")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.primary)
        }
        .padding(.bottom, 2)
    }

    private var emptyState: some View {
        Text("An open day.")
            .font(.appSerif(size: 14, italic: true, simple: entry.useSimpleFont))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
    }
}
