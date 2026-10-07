import SwiftUI

/// Tap-the-flame explainer. Surfaces what counts as a streak day, how
/// freezes work, and where to find the full history.
struct StreakExplanationSheet: View {
    let streakLength: Int
    let onDismiss: () -> Void

    private struct Bullet: Identifiable {
        let id = UUID()
        let symbol: String
        let title: LocalizedStringKey
        let body: LocalizedStringKey
    }

    private let bullets: [Bullet] = [
        Bullet(
            symbol: "calendar",
            title: "What counts as a day",
            body: "Any meal logged today keeps your streak going."
        ),
        Bullet(
            symbol: "snowflake",
            title: "Freeze saves a missed day",
            body:
                "In the afternoon, if you haven't entered anything, a freeze button appears. It uses up one of your two weekly saves."
        ),
        Bullet(
            symbol: "arrow.triangle.2.circlepath",
            title: "Reset po cichu",
            body:
                """
                Skipping a full 24-hour period without a freeze resets the counter to zero. No big deal — you can start a new \
                streak right away.
                """
        ),
        Bullet(
            symbol: "clock.arrow.circlepath",
            title: "Pełna historia w Profilu",
            body: "Profil → Historia serii pokazuje miesięczną kratę z każdym zalogowanym dniem."
        ),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                        .padding(.top, 10)
                    MonoH1(text: L("How the streak works"))
                        .padding(.top, 10)
                    bulletsCard
                        .padding(.top, 16)
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.bottom, Tokens.Space.lg)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(Tokens.Palette.background.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                MonoBottomBar {
                    MonoButton(title: L("Close"), kind: .dark, action: onDismiss)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    MonoNavText(title: L("Close"), action: onDismiss)
                }
            }
        }
    }

    // Mockup hero: "TWOJA SERIA" label, 84 pt italic number, "dni z rzędu".
    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            MonoLabel(text: L("Your streak"), onHero: true)
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(verbatim: "\(streakLength)")
                    .font(Tokens.Font.monoNumber(84))
                    .foregroundStyle(Tokens.Mono.onHero)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .contentTransition(.numericText())
                Text(L("days in a row"))
                    .font(Tokens.Font.manrope(16, weight: 800))
                    .foregroundStyle(Tokens.Mono.onHero)
            }
        }
        .monoHero(padding: 22)
        .accessibilityElement(children: .combine)
    }

    // Mockup: one card (padding 20, gap 20) listing icon + title + muted body.
    private var bulletsCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(bullets) { item in
                bulletRow(item)
            }
        }
        .monoCard(padding: 20)
    }

    private func bulletRow(_ item: Bullet) -> some View {
        HStack(alignment: .top, spacing: 14) {
            MonoIconBox(systemName: item.symbol, style: .track, size: 40)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(Tokens.Font.manrope(16, weight: 800))
                    .foregroundStyle(Tokens.Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(item.body)
                    .font(Tokens.Font.manrope(13, weight: 600))
                    .foregroundStyle(Tokens.Mono.muted)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}
