import SwiftUI

/// The collapsed-paper composition: binding holes, weekday name, big day
/// numeral with today underline, perforation. No weather.
///
/// Mirrors what `DayView` shows when `scheduleProgress == 1` (collapsed
/// state), minus everything that the collapse fades away anyway.
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
        ZStack(alignment: .top) {
            // Paper background comes from the widget's containerBackground.
            // We lay out the chrome + content on top of it.
            BindingHoles()

            VStack(spacing: 4) {
                Spacer(minLength: 0)
                Text(DayNames.full[SampleData.weekday(year: year, month: month, day: day)])
                    .font(.appSerif(size: 14, italic: true, simple: useSimpleFont))
                    .foregroundStyle(.primary)
                Text(verbatim: "\(day)")
                    .font(.appSerif(size: 72, simple: useSimpleFont))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .overlay(alignment: .bottom) {
                        if isToday {
                            Rectangle()
                                .fill(.primary)
                                .frame(width: 56, height: 1.2)
                                .offset(y: -6)
                        }
                    }
                Spacer(minLength: 0)
            }
            .padding(.top, 28)
            .padding(.bottom, 12)

            VStack {
                Spacer()
                PerforationEdge()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(DayNames.full[SampleData.weekday(year: year, month: month, day: day)]), \(MonthNames.full[month - 1]) \(day)"))
    }
}
