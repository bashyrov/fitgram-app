import SwiftUI

/// Soft sage banner highlighting a Polish food event ≤ 7 days away. Shown
/// between the AI insight card and the meal timeline on the Today screen.
struct CulturalEventBanner: View {
    let upcoming: CulturalEventService.Upcoming
    var onDismiss: (() -> Void)?

    var body: some View {
        Card(background: Tokens.Palette.primarySoft, elevation: Tokens.Shadow.card) {
            HStack(alignment: .top, spacing: Tokens.Space.md) {
                ZStack {
                    Circle()
                        .fill(Tokens.Palette.primary)
                        .frame(width: 36, height: 36)
                    Image(systemName: upcoming.event.symbol)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(LocalizedStringKey(upcoming.event.name))
                            .font(Tokens.Font.bodyEmphasized)
                            .foregroundStyle(Tokens.Palette.ink)
                        Spacer(minLength: 0)
                        Text(badge)
                            .font(Tokens.Font.caption)
                            .foregroundStyle(Tokens.Palette.primary)
                            .padding(.horizontal, Tokens.Space.sm)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.white.opacity(0.6)))
                    }
                    Text(LocalizedStringKey(upcoming.event.foodNote))
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let onDismiss {
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption)
                            .foregroundStyle(Tokens.Palette.inkMuted)
                            .padding(6)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Ukryj"))
                }
            }
        }
    }

    private var badge: String {
        if upcoming.isToday { return L("dziś") }
        if upcoming.daysAway == 1 { return L("jutro") }
        let format = L("za %lld dni")
        return String.localizedStringWithFormat(format, upcoming.daysAway)
    }
}
