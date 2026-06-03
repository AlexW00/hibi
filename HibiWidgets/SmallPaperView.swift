import SwiftUI

/// The collapsed-paper composition: binding holes, weekday name, big day
/// numeral with today underline, perforation. No weather.
///
/// Mirrors what `DayView` shows when `scheduleProgress == 1` (collapsed
/// state), minus everything that the collapse fades away anyway. Sized for
/// the `.systemSmall` widget (~158pt square) — chrome spacing is tighter
/// than the in-app paper card and content is anchored from the top rather
/// than vertically centered, so the weekday hugs the binding holes and the
/// numeral grows toward the perforation.
struct SmallPaperView: View {
    let day: Int
    let month: Int
    let year: Int
    /// Always true in this widget (we only render today). Carried as a
    /// parameter so the rendering code stays parallel with `LargePaperView`
    /// and the in-app paper.
    let isToday: Bool

    @AppStorage("useSimpleFont", store: AppGroup.defaults) private var useSimpleFont: Bool = false

    var body: some View {
        ZStack {
            // Chrome anchored to the widget edges.
            VStack(spacing: 0) {
                BindingHoles(spacing: 28, diameter: 7, topPadding: 10)
                Spacer(minLength: 0)
                PerforationEdge()
            }

            // Content anchored below the binding holes.
            VStack(spacing: 0) {
                Spacer().frame(height: 22)
                Text(DayNames.full[SampleData.weekday(year: year, month: month, day: day)])
                    .font(.appSerif(size: 14, italic: true, simple: useSimpleFont))
                    .foregroundStyle(.primary)
                Text(verbatim: "\(day)")
                    .font(.appSerif(size: 84, simple: useSimpleFont))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .overlay(alignment: .bottom) {
                        if isToday {
                            Rectangle()
                                .fill(.primary)
                                .frame(width: 58, height: 1.3)
                                .offset(y: -8)
                        }
                    }
                    // CJK serif faces have a far deeper ascent than Instrument
                    // Serif; in this top-anchored layout that empty space above
                    // the baseline would otherwise push the numeral and its
                    // underline down toward the perforation. Lift them back to
                    // the Latin position. No-op in Latin / system-font locales.
                    .padding(.top, -AppFont.cjkNumeralTopCompensation(numeralSize: 84, weekdaySize: 14, simple: useSimpleFont))
                Spacer(minLength: 0)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(DayNames.full[SampleData.weekday(year: year, month: month, day: day)]), \(MonthNames.full[month - 1]) \(day)"))
    }
}
