import SwiftUI

/// Alternating bands, each carrying one faint "FITGRAMFITGRAM…" row. Rows
/// start at scattered offsets and run past both edges. Dark palettes get
/// light words on the hero colour, light palettes ink words on paper.
struct WordmarkStripes: View {
    private static let bandHeight: CGFloat = 58
    /// Fixed pseudo-random offsets (fraction of one word) and repeat
    /// counts, so the pattern is chaotic but identical on every launch.
    private static let offsets: [Double] = [0.62, 0.08, 0.91, 0.37, 0.74, 0.19, 0.55, 0.97, 0.28, 0.83, 0.44, 0.03]
    private static let repeats = [5, 6, 4, 6, 5, 4, 6, 5, 4, 6, 5, 6]

    var body: some View {
        GeometryReader { proxy in
            let rows = Int((proxy.size.height / Self.bandHeight).rounded(.up))
            VStack(alignment: .leading, spacing: 0) {
                ForEach(0..<rows, id: \.self) { row in
                    band(row)
                }
            }
            .frame(width: proxy.size.width, alignment: .leading)
            .clipped()
        }
        .background(Tokens.Mono.Brand.background)
        .accessibilityHidden(true)
    }

    private func band(_ row: Int) -> some View {
        let offset = Self.offsets[row % Self.offsets.count]
        let count = Self.repeats[row % Self.repeats.count]
        // One "FITGRAM" at this size is ~190 pt wide; shift left by a
        // fraction of it so word starts never line up between rows.
        return Text(verbatim: String(repeating: "FITGRAM", count: count))
            .font(Tokens.Font.monoDisplay(44))
            .foregroundStyle(Tokens.Mono.Brand.text.opacity(Tokens.Mono.Brand.isLight ? 0.07 : 0.10))
            .lineLimit(1)
            .fixedSize()
            .offset(x: -CGFloat(offset) * 190 - 30)
            .frame(height: Self.bandHeight, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                row.isMultiple(of: 2)
                    ? Color.clear : Tokens.Mono.Brand.text.opacity(Tokens.Mono.Brand.isLight ? 0.03 : 0.035))
    }
}

/// Full-width FIT mark with "GRAM" underneath — the brand lockup on the
/// welcome, sign-in and splash screens.
struct FitgramWordmarkLockup: View {
    var appeared = true

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            FitgramLogoMark(color: Tokens.Mono.Brand.logo)
                .aspectRatio(240.0 / 112.0, contentMode: .fit)
                .frame(maxWidth: .infinity, alignment: .leading)
                .opacity(appeared ? 1 : 0)
                .offset(x: appeared ? 0 : -60)
            Text(verbatim: "GRAM")
                .font(Tokens.Font.monoDisplay(320))
                .foregroundStyle(Tokens.Mono.Brand.text)
                .lineLimit(1)
                .minimumScaleFactor(0.05)
                .frame(maxWidth: .infinity, alignment: .leading)
                .opacity(appeared ? 1 : 0)
                .offset(x: appeared ? 0 : 60)
        }
        .accessibilityElement()
        .accessibilityLabel(Text(verbatim: "Fitgram"))
    }
}
