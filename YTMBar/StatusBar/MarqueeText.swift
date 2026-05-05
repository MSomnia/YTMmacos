import SwiftUI

private struct NaturalWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// A text view that scrolls horizontally (marquee) when its content exceeds
/// `containerWidth`, and renders statically when it fits.
struct MarqueeText: View {
    let text: String
    let containerWidth: CGFloat
    var font: Font = .system(size: 12)
    var italic: Bool = false
    /// Points per second the text travels.
    var speed: Double = 30
    /// Seconds to hold still at each end before scrolling.
    var pauseAt: Double = 1

    @State private var naturalWidth: CGFloat = 0

    private var scrollDistance: CGFloat { max(0, naturalWidth - containerWidth) }

    private var cycleDuration: Double {
        guard scrollDistance > 0 else { return 1 }
        return pauseAt + Double(scrollDistance) / speed + pauseAt
    }

    private func xOffset(for date: Date) -> CGFloat {
        guard scrollDistance > 0 else { return 0 }
        let t = date.timeIntervalSinceReferenceDate
            .truncatingRemainder(dividingBy: cycleDuration)
        if t < pauseAt {
            return 0
        } else if t < pauseAt + Double(scrollDistance) / speed {
            return -CGFloat((t - pauseAt) * speed)
        } else {
            return -scrollDistance
        }
    }

    var body: some View {
        ZStack(alignment: .leading) {
            // Hidden text used only to measure natural (unconstrained) width.
            label(text)
                .fixedSize()
                .hidden()
                .background(
                    GeometryReader { g in
                        Color.clear.preference(key: NaturalWidthKey.self, value: g.size.width)
                    }
                )

            if scrollDistance > 0 {
                TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { ctx in
                    label(text)
                        .fixedSize()
                        .offset(x: xOffset(for: ctx.date))
                }
            } else {
                label(text).lineLimit(1)
            }
        }
        .frame(width: containerWidth, alignment: .leading)
        .clipped()
        .onPreferenceChange(NaturalWidthKey.self) { naturalWidth = $0 }
    }

    @ViewBuilder
    private func label(_ t: String) -> some View {
        Text(t)
            .font(font)
            .italic(italic)
            .foregroundStyle(.primary)
    }
}
