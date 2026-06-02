import AppIntents
import SwiftUI
import WidgetKit

/// The Schedule widget — today's events and reminders as pastel pills.
/// Adapts to three families and five content states (empty / 1 / 2 / 3 / >3
/// items), where "items" = reminders + events.
///
/// Visual language follows the in-app `DayEventRow` and `ReminderRow`
/// (tint @ 0.10 base, 0.26 progress fill, 0.35 border, monospaced time +
/// sans title, leading checkbox column for reminders) scaled down to the
/// widget's tighter typographic footprint.
struct EventsWidgetView: View {
    let entry: EventsEntry

    @Environment(\.widgetFamily) private var family

    private var isPlus: Bool { PlusEntitlementStore().isPlus }

    var body: some View {
        content.plusLocked(!isPlus)
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .systemLarge:
            EventsWidgetLargeBody(entry: entry)
        case .systemMedium:
            EventsWidgetBody(entry: entry, isMedium: true)
        default:
            EventsWidgetBody(entry: entry, isMedium: false)
        }
    }
}

// MARK: - Combined schedule item

/// What the widget actually renders is a unified stack: reminders first,
/// events after. `ScheduleItem` lets pill / hero layouts iterate over both
/// kinds with shared edge logic, the same way `DayView.scheduleEvents`
/// stacks them in-app.
private enum ScheduleItem: Identifiable {
    case reminder(WidgetEventsSnapshot.Reminder)
    case event(WidgetEventsSnapshot.Event)

    var id: String {
        switch self {
        case .reminder(let r): return "r-\(r.id)"
        case .event(let e): return "e-\(e.id)"
        }
    }
}

private extension EventsEntry {
    /// Reminders are rendered above events to mirror the in-app schedule
    /// stack (the Day tab puts reminders first too).
    var items: [ScheduleItem] {
        reminders.map(ScheduleItem.reminder) + events.map(ScheduleItem.event)
    }
}

// MARK: - Sizing constants

private enum WidgetMetrics {
    /// Symmetrical padding inside the widget shell — matches the design's
    /// "tight, equal margin" variant so pill corners trace the widget edge.
    static func pad(isMedium: Bool) -> CGFloat { isMedium ? 9 : 7 }
    /// Gap between pills. Tightened on small (where vertical real estate
    /// is precious) and in the >3 peek state so the fourth row reaches the
    /// fade zone without the gaps eating the row heights.
    static func gap(isMedium: Bool, peek: Bool = false) -> CGFloat {
        if peek { return 5 }
        return isMedium ? 7 : 5
    }
    /// Outer corner radius — used on corners that sit against the widget
    /// host's rounded shape so the pill visually traces the widget edge.
    /// Inner corners (between adjacent pills) use the shared
    /// `EventRowEdges.innerRadius`, so the gap between rows reads the
    /// same on the widget as in the app's Day list.
    static let outerRadius: CGFloat = 22
}

// MARK: - Body

private struct EventsWidgetBody: View {
    let entry: EventsEntry
    let isMedium: Bool

    var body: some View {
        let pad = WidgetMetrics.pad(isMedium: isMedium)
        let items = entry.items

        Group {
            switch items.count {
            case 0:
                EmptyOpenPage(isMedium: isMedium)
            case 1:
                heroFor(items[0])
            case 2, 3:
                FillPills(items: items, now: entry.date, isMedium: isMedium)
            default:
                PeekPills(items: items, now: entry.date, isMedium: isMedium)
            }
        }
        .padding(pad)
    }

    @ViewBuilder
    private func heroFor(_ item: ScheduleItem) -> some View {
        switch item {
        case .event(let event):
            DeepLink(eventID: event.id) {
                HeroEventCard(event: event, now: entry.date, isMedium: isMedium)
            }
        case .reminder(let reminder):
            HeroReminderCard(reminder: reminder, isMedium: isMedium)
        }
    }
}

// MARK: - Large (4×4 cell) body

private struct EventsWidgetLargeBody: View {
    let entry: EventsEntry

    var body: some View {
        let pad = WidgetMetrics.pad(isMedium: true)
        let items = entry.items

        Group {
            switch items.count {
            case 0:
                EmptyOpenPage(isMedium: true)
            case 1:
                switch items[0] {
                case .event(let event):
                    // Single event reads as featured editorial content even
                    // at the larger 4×4 size — same Hero treatment as on
                    // medium.
                    DeepLink(eventID: event.id) {
                        HeroEventCard(event: event, now: entry.date, isMedium: true)
                    }
                case .reminder(let reminder):
                    HeroReminderCard(reminder: reminder, isMedium: true)
                }
            default:
                LargeList(items: items, now: entry.date)
            }
        }
        .padding(pad)
    }
}

/// The large widget's multi-item layout. Pills size to the same 48pt
/// minimum as in-app rows — no stretching to fill the widget, no
/// compressing to a smaller fixed height. If the day's items run past
/// the widget bottom, the overflow fades; otherwise the stack just
/// anchors to the top with empty space below.
private struct LargeList: View {
    let items: [ScheduleItem]
    let now: Date

    var body: some View {
        let last = items.count - 1
        let gap = WidgetMetrics.gap(isMedium: true, peek: true)

        // Conservative overflow heuristic: ~336pt usable height ÷ (48pt
        // row + 5pt gap) ≈ 6 full rows. Past that the stack pushes into
        // the bottom of the widget and the gradient mask fades it out.
        let overflows = items.count > 6

        VStack(spacing: gap) {
            ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                pill(
                    for: item,
                    edges: EventRowEdges(
                        top: idx == 0,
                        // When the day overflows the bottom edge, no row
                        // claims the bottom outer corner — the fade owns
                        // it. Otherwise the last row picks it up.
                        bottom: !overflows && idx == last
                    )
                )
                .frame(minHeight: 48)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .mask(
            LinearGradient(
                stops: overflows
                    ? [
                        .init(color: .black, location: 0.0),
                        .init(color: .black, location: 0.88),
                        .init(color: .clear, location: 1.0),
                    ]
                    : [
                        .init(color: .black, location: 0.0),
                        .init(color: .black, location: 1.0),
                    ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    @ViewBuilder
    private func pill(for item: ScheduleItem, edges: EventRowEdges) -> some View {
        switch item {
        case .event(let event):
            DeepLink(eventID: event.id) {
                EventPill(event: event, now: now, isMedium: true, edges: edges)
            }
        case .reminder(let reminder):
            ReminderPill(reminder: reminder, isMedium: true, edges: edges)
        }
    }
}

// MARK: - Empty state ("Open page")

private struct EmptyOpenPage: View {
    let isMedium: Bool

    @AppStorage("useSimpleFont", store: AppGroup.defaults) private var useSimpleFont: Bool = false

    var body: some View {
        VStack(spacing: 8) {
            Circle()
                .fill(.primary.opacity(0.30))
                .frame(width: isMedium ? 8 : 7, height: isMedium ? 8 : 7)
            // Already-localized elsewhere in the app (Day tab empty state).
            Text("An open day.")
                .font(.appSerif(size: isMedium ? 16 : 13, italic: true, simple: useSimpleFont))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Deep-link helper

/// Wraps a pill in a `Link` that opens the tapped event in the app's
/// editor. Per-event deep links coexist with the widget's outer
/// `.widgetURL("hibi://today")`: Link's tap target takes priority within
/// its bounds, so taps that miss any pill (or land on empty space) still
/// fall through to the widget-wide URL.
private struct DeepLink<Content: View>: View {
    let eventID: String
    @ViewBuilder var content: () -> Content

    private var isPlus: Bool { PlusEntitlementStore().isPlus }

    var body: some View {
        if isPlus {
            Link(destination: URL(string: "hibi://event/\(eventID)") ?? URL(string: "hibi://today")!) {
                content()
            }
        } else {
            content()
        }
    }
}

// MARK: - Hero card (1 event)

private struct HeroEventCard: View {
    let event: WidgetEventsSnapshot.Event
    let now: Date
    let isMedium: Bool

    @AppStorage(TimeFormat.defaultsKey, store: AppGroup.defaults)
    private var timeFormatRaw: String = TimeFormat.system.rawValue
    @AppStorage("useSimpleFont", store: AppGroup.defaults)
    private var useSimpleFont: Bool = false

    private var timeFormat: TimeFormat {
        TimeFormat(rawValue: timeFormatRaw) ?? .system
    }

    private var tint: Color {
        Color.pastelized(cgColor: event.tintRGB.cgColor)
    }

    private var progress: Double {
        eventProgress(event: event, now: now)
    }

    private var timeRangeText: String {
        if event.allDay { return String(localized: "ALL DAY") }
        guard let s = event.startDate, let e = event.endDate else { return "" }
        return "\(timeFormat.string(from: s))–\(timeFormat.string(from: e))"
    }

    var body: some View {
        let shape = EventRowEdges.solo.shape(outer: WidgetMetrics.outerRadius)

        VStack(alignment: .leading, spacing: 0) {
            Text(timeRangeText)
                .font(.system(size: isMedium ? 10 : 9, weight: .semibold, design: .monospaced))
                .tracking(0.4)
                .foregroundStyle(tint.mix(with: .black, by: 0.20))

            Text(event.title)
                .font(.appSerif(size: isMedium ? 22 : 16, italic: true, simple: useSimpleFont))
                .foregroundStyle(.primary)
                .tracking(-0.2)
                .lineLimit(2)
                .padding(.top, isMedium ? 4 : 2)

            Spacer(minLength: 0)

            if let loc = event.location, !loc.isEmpty {
                Text(loc)
                    .font(.system(size: isMedium ? 11 : 9.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, isMedium ? 14 : 11)
        .padding(.vertical, isMedium ? 12 : 10)
        // Stack matches DayEventRow: progress fill on top of base tint, both
        // clipped to the same rounded rectangle.
        .background(alignment: .leading) {
            Rectangle()
                .fill(tint.opacity(event.allDay ? 0.28 : 0.26))
                .scaleEffect(x: CGFloat(progress), y: 1, anchor: .leading)
        }
        .background(tint.opacity(event.allDay ? 0.38 : 0.10))
        .clipShape(shape)
        .overlay(shape.strokeBorder(tint.opacity(0.35), lineWidth: 0.5))
    }
}

// MARK: - Hero card (1 reminder)

private struct HeroReminderCard: View {
    let reminder: WidgetEventsSnapshot.Reminder
    let isMedium: Bool

    @AppStorage(TimeFormat.defaultsKey, store: AppGroup.defaults)
    private var timeFormatRaw: String = TimeFormat.system.rawValue
    @AppStorage("useSimpleFont", store: AppGroup.defaults)
    private var useSimpleFont: Bool = false

    private var timeFormat: TimeFormat {
        TimeFormat(rawValue: timeFormatRaw) ?? .system
    }

    private var tint: Color {
        Color.pastelized(cgColor: reminder.tintRGB.cgColor)
    }

    private var topLabel: String? {
        if reminder.hasTime, let due = reminder.dueDate {
            return timeFormat.string(from: due)
        }
        if reminder.dueDate != nil {
            return String(localized: "Today")
        }
        return nil
    }

    private var bottomLabel: String? {
        if reminder.isOverdue {
            return String(localized: "Overdue")
        }
        return nil
    }

    var body: some View {
        let shape = EventRowEdges.solo.shape(outer: WidgetMetrics.outerRadius)

        HStack(alignment: .top, spacing: 0) {
            ReminderCheckbox(
                reminderID: reminder.reminderIdentifier,
                isCompleted: reminder.isCompleted,
                tint: tint,
                isMedium: isMedium,
                isHero: true
            )

            VStack(alignment: .leading, spacing: 0) {
                if let topLabel {
                    Text(topLabel)
                        .font(.system(size: isMedium ? 10 : 9, weight: .semibold, design: .monospaced))
                        .tracking(0.4)
                        .foregroundStyle(tint.mix(with: .black, by: 0.20))
                }

                Text(reminder.title)
                    .font(.appSerif(size: isMedium ? 22 : 16, italic: true, simple: useSimpleFont))
                    .foregroundStyle(.primary)
                    .strikethrough(reminder.isCompleted)
                    .tracking(-0.2)
                    .lineLimit(2)
                    .padding(.top, isMedium ? 4 : 2)

                Spacer(minLength: 0)

                if let bottomLabel {
                    Text(bottomLabel)
                        .font(.system(size: isMedium ? 11 : 9.5, weight: .semibold))
                        .foregroundStyle(Color.red.opacity(0.8))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.trailing, isMedium ? 14 : 11)
            .padding(.vertical, isMedium ? 12 : 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(tint.opacity(reminder.isCompleted ? 0.38 : 0.10))
        .clipShape(shape)
        .overlay(shape.strokeBorder(tint.opacity(0.35), lineWidth: 0.5))
    }
}

// MARK: - Fill pills (2 or 3 items)

private struct FillPills: View {
    let items: [ScheduleItem]
    let now: Date
    let isMedium: Bool

    var body: some View {
        let last = items.count - 1
        VStack(spacing: WidgetMetrics.gap(isMedium: isMedium)) {
            ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                pill(
                    for: item,
                    edges: EventRowEdges(top: idx == 0, bottom: idx == last)
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func pill(for item: ScheduleItem, edges: EventRowEdges) -> some View {
        switch item {
        case .event(let event):
            DeepLink(eventID: event.id) {
                EventPill(event: event, now: now, isMedium: isMedium, edges: edges)
            }
        case .reminder(let reminder):
            ReminderPill(reminder: reminder, isMedium: isMedium, edges: edges)
        }
    }
}

// MARK: - Peek pills (>3 items)

private struct PeekPills: View {
    let items: [ScheduleItem]
    let now: Date
    let isMedium: Bool

    /// Show four rows total; the fourth fades into the widget edge to
    /// imply there's more below.
    private var visible: [ScheduleItem] {
        Array(items.prefix(4))
    }

    var body: some View {
        // `.fixedSize(vertical:)` lets the inner VStack take exactly its
        // children's combined height — about 152pt for four 32pt rows with
        // 8pt gaps — even when the outer .frame is only ~140pt tall. That
        // controlled overflow is what makes the fourth row sit *inside* the
        // mask's fade zone. The outer frame anchors top so overflow runs
        // off the bottom; the system's widget clip handles the hard edge.
        VStack(spacing: WidgetMetrics.gap(isMedium: isMedium, peek: true)) {
            ForEach(Array(visible.enumerated()), id: \.element.id) { idx, item in
                // Only the first row sits against the widget's top edge.
                // The fourth row runs past the bottom into the mask's fade —
                // no row is "at" the bottom edge, so all bottoms stay inner.
                pill(
                    for: item,
                    edges: EventRowEdges(top: idx == 0, bottom: false)
                )
                .frame(height: 32)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .black, location: 0.0),
                    .init(color: .black, location: 0.72),
                    .init(color: .clear, location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    @ViewBuilder
    private func pill(for item: ScheduleItem, edges: EventRowEdges) -> some View {
        switch item {
        case .event(let event):
            DeepLink(eventID: event.id) {
                EventPill(event: event, now: now, isMedium: isMedium, edges: edges)
            }
        case .reminder(let reminder):
            ReminderPill(reminder: reminder, isMedium: isMedium, edges: edges)
        }
    }
}

// MARK: - Event pill

private struct EventPill: View {
    let event: WidgetEventsSnapshot.Event
    let now: Date
    let isMedium: Bool
    let edges: EventRowEdges

    @AppStorage(TimeFormat.defaultsKey, store: AppGroup.defaults)
    private var timeFormatRaw: String = TimeFormat.system.rawValue

    private var timeFormat: TimeFormat {
        TimeFormat(rawValue: timeFormatRaw) ?? .system
    }

    private var tint: Color {
        Color.pastelized(cgColor: event.tintRGB.cgColor)
    }

    private var progress: Double {
        eventProgress(event: event, now: now)
    }

    private var startText: String {
        if event.allDay { return String(localized: "ALL DAY") }
        return event.startDate.map { timeFormat.string(from: $0) } ?? ""
    }

    var body: some View {
        let shape = edges.shape(outer: WidgetMetrics.outerRadius)

        HStack(spacing: 0) {
            // Monospaced time column. "ALL DAY" wraps to two lines and
            // shrinks to fit — localized variants like German GANZTÄGIG or
            // Italian "TUTTO IL GIORNO" otherwise overflow the 40pt column
            // on the small widget.
            Text(startText)
                .font(.system(
                    size: isMedium ? 9.5 : 8.5,
                    weight: .semibold,
                    design: .monospaced
                ))
                .tracking(0.3)
                .foregroundStyle(tint.mix(with: .black, by: 0.20))
                .multilineTextAlignment(.center)
                .lineLimit(event.allDay ? 2 : 1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 2)
                .frame(width: isMedium ? 50 : 40)
                .frame(maxHeight: .infinity)

            // Tint hairline rail.
            Rectangle()
                .fill(tint.opacity(0.45))
                .frame(width: 1)

            // Title + (medium only) location.
            VStack(alignment: .leading, spacing: 1) {
                Text(event.title)
                    .font(.system(size: isMedium ? 11 : 10, weight: .medium))
                    .tracking(-0.1)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if isMedium, let loc = event.location, !loc.isEmpty {
                    Text(loc)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, isMedium ? 9 : 8)
            .padding(.vertical, isMedium ? 5 : 4)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(alignment: .leading) {
            Rectangle()
                .fill(tint.opacity(event.allDay ? 0.28 : 0.26))
                .scaleEffect(x: CGFloat(progress), y: 1, anchor: .leading)
        }
        .background(tint.opacity(event.allDay ? 0.38 : 0.10))
        .clipShape(shape)
        .overlay(shape.strokeBorder(tint.opacity(0.35), lineWidth: 0.5))
    }
}

// MARK: - Reminder pill

private struct ReminderPill: View {
    let reminder: WidgetEventsSnapshot.Reminder
    let isMedium: Bool
    let edges: EventRowEdges

    @AppStorage(TimeFormat.defaultsKey, store: AppGroup.defaults)
    private var timeFormatRaw: String = TimeFormat.system.rawValue

    private var timeFormat: TimeFormat {
        TimeFormat(rawValue: timeFormatRaw) ?? .system
    }

    private var tint: Color {
        Color.pastelized(cgColor: reminder.tintRGB.cgColor)
    }

    private var subtitle: String? {
        var parts: [String] = []
        if reminder.hasTime, let due = reminder.dueDate {
            parts.append(timeFormat.string(from: due))
        }
        if reminder.isOverdue {
            parts.append(String(localized: "Overdue"))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    var body: some View {
        let shape = edges.shape(outer: WidgetMetrics.outerRadius)

        HStack(spacing: 0) {
            ReminderCheckbox(
                reminderID: reminder.reminderIdentifier,
                isCompleted: reminder.isCompleted,
                tint: tint,
                isMedium: isMedium,
                isHero: false
            )

            // Tint hairline rail — matches event pill so reminders and
            // events read as the same vertical column system.
            Rectangle()
                .fill(tint.opacity(0.45))
                .frame(width: 1)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(reminder.title)
                        .font(.system(size: isMedium ? 11 : 10, weight: .medium))
                        .tracking(-0.1)
                        .strikethrough(reminder.isCompleted)
                        .foregroundStyle(reminder.isCompleted ? .secondary : .primary)
                        .lineLimit(1)
                }

                if isMedium, let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(reminder.isOverdue ? Color.red.opacity(0.8) : .secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, isMedium ? 9 : 8)
            .padding(.vertical, isMedium ? 5 : 4)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(tint.opacity(reminder.isCompleted ? 0.38 : 0.10))
        .clipShape(shape)
        .overlay(shape.strokeBorder(tint.opacity(0.35), lineWidth: 0.5))
    }
}

// MARK: - Reminder checkbox button

/// The single interactive primitive on a reminder row. Hosts a
/// `Button(intent:)` that runs `ToggleReminderCompletionIntent` in the
/// widget extension process — no app launch. The button's frame matches
/// the event pill's leading time column so reminders + events line up
/// visually in mixed lists.
private struct ReminderCheckbox: View {
    let reminderID: String
    let isCompleted: Bool
    let tint: Color
    let isMedium: Bool
    /// Hero variant uses a larger glyph and a wider hit area to match
    /// the editorial scale of the rest of the hero card.
    let isHero: Bool

    private var isPlus: Bool { PlusEntitlementStore().isPlus }

    var body: some View {
        let width: CGFloat = {
            if isHero { return isMedium ? 64 : 52 }
            return isMedium ? 50 : 40
        }()
        let glyph: CGFloat = isHero ? (isMedium ? 22 : 18) : (isMedium ? 16 : 14)

        Group {
            if isPlus {
                Button(intent: ToggleReminderCompletionIntent(reminderID: reminderID)) {
                    checkmarkIcon(glyph: glyph)
                }
                .buttonStyle(.plain)
                .invalidatableContent()
            } else {
                checkmarkIcon(glyph: glyph)
            }
        }
        .frame(width: width)
        .frame(maxHeight: .infinity)
    }

    private func checkmarkIcon(glyph: CGFloat) -> some View {
        Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
            .font(.system(size: glyph, weight: .medium))
            .foregroundStyle(tint.mix(with: .black, by: 0.10))
            .contentTransition(.symbolEffect(.replace))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Helpers

/// Linear progress through the event's timespan. 0 before start, 1 after end.
/// All-day events always render as fully filled (matches `DayEventRow`).
private func eventProgress(event: WidgetEventsSnapshot.Event, now: Date) -> Double {
    if event.allDay { return 1 }
    guard let s = event.startDate, let e = event.endDate, e > s else { return 0 }
    if now <= s { return 0 }
    if now >= e { return 1 }
    return now.timeIntervalSince(s) / e.timeIntervalSince(s)
}

private extension WidgetEventsSnapshot.RGBA {
    /// Rebuild a CGColor in displayP3 from the stored components so the
    /// widget can re-run `Color.pastelized(cgColor:)` and get a dynamic
    /// (light/dark-aware) tint at render time.
    var cgColor: CGColor {
        CGColor(
            colorSpace: CGColorSpace(name: CGColorSpace.displayP3)!,
            components: [CGFloat(red), CGFloat(green), CGFloat(blue), CGFloat(alpha)]
        ) ?? UIColor.systemGray.cgColor
    }
}
