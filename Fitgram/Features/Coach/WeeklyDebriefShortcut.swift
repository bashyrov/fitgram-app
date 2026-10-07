import SwiftUI

/// Compact "How you're doing" link on Today — opens the weekly debrief sheet.
/// Design D: a single `row` inside a rows card (track icon box, title, sub, chevron).
struct WeeklyDebriefShortcut: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            MonoRow(
                icon: "chart.line.uptrend.xyaxis",
                iconStyle: .track,
                title: L("How you're doing"),
                sub: L("Weekly summary from Ola")
            )
            .monoRowsCard()
        }
        .buttonStyle(PressableButtonStyle())
    }
}
