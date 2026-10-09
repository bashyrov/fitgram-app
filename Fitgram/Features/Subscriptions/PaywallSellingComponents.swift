import SwiftUI

/// Dark hero shared by the in-app and onboarding paywalls: benefit-led
/// headline, value pills and the trial banner.
struct PaywallHero: View {
    let trialDays: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                MonoLabel(text: L("FITGRAM PRO"), onHero: true)
                Spacer()
                Image(systemName: "crown.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Tokens.Mono.onHi)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Tokens.Mono.hi))
            }
            Text(L("Jedz normalnie. Chudnij mądrze."))
                .font(Tokens.Font.monoDisplay(32))
                .textCase(.uppercase)
                .foregroundStyle(Tokens.Mono.onHero)
                .lineLimit(3)
                .minimumScaleFactor(0.7)
                .fixedSize(horizontal: false, vertical: true)
            Text(L("AI policzy kalorie z jednego zdjęcia, a Ola poprowadzi Cię do celu — bez liczenia w głowie."))
                .font(Tokens.Font.manrope(14, weight: 600))
                .foregroundStyle(Tokens.Mono.heroMuted)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 6) {
                pill(symbol: "camera.viewfinder", title: L("Skan w 5 s"))
                pill(symbol: "infinity", title: L("Bez limitów"))
                pill(symbol: "sparkles", title: L("Coach Ola"))
            }
            if let trialDays {
                trialBanner(days: trialDays)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Mono.Radius.hero, style: .continuous)
                .fill(Tokens.Mono.hero)
        )
    }

    private func trialBanner(days: Int) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "gift.fill")
                .font(.system(size: 18, weight: .bold))
            VStack(alignment: .leading, spacing: 2) {
                Text(String.localizedStringWithFormat(L("%lld dni za darmo"), days))
                    .font(Tokens.Font.manrope(15, weight: 800))
                Text(L("Bez opłat dziś. Anulujesz jednym kliknięciem."))
                    .font(Tokens.Font.manrope(12, weight: 600))
                    .opacity(0.8)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(Tokens.Mono.onHi)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Mono.Radius.tile, style: .continuous)
                .fill(Tokens.Mono.hi)
        )
    }

    private func pill(symbol: String, title: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .bold))
            Text(title)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .font(Tokens.Font.manrope(12, weight: 800))
        .foregroundStyle(Tokens.Mono.onHero)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity)
        .frame(height: 32)
        .background(Capsule().fill(Tokens.Mono.heroLine))
    }
}

/// "What you get in Pro" — outcome-led benefit rows.
struct PaywallBenefitList: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PaywallSectionTitle(title: L("Co dostajesz w Pro"))
            VStack(spacing: 14) {
                row(
                    symbol: "camera.viewfinder",
                    title: L("Skanowanie zdjęć bez dziennego limitu"),
                    text: L("Zrób zdjęcie talerza — kalorie i makro w kilka sekund."))
                row(
                    symbol: "sparkles",
                    title: L("Ola — Twój osobisty coach AI"),
                    text: L("Codzienne porady i tygodniowe podsumowania pod Twój cel."))
                row(
                    symbol: "book",
                    title: L("Przepisy i Kuchnia Oli"),
                    text: L("Gotowe dania z policzonym makro, dopasowane do diety."))
                row(
                    symbol: "chart.line.uptrend.xyaxis",
                    title: L("Pełna historia i eksport"),
                    text: L("Wykresy postępów oraz CSV i ZIP dla dietetyka."))
                row(
                    symbol: "text.bubble",
                    title: TL(
                        pl: "Posty dla znajomych", en: "Posts for friends", uk: "Пости для друзів",
                        ru: "Посты для друзей", es: "Publicaciones para amigos"),
                    text: TL(
                        pl:
                            "Do \(PostLimits.dailyMax) postów dziennie ze zdjęciem i makro, plus znaczek Premium przy imieniu.",
                        en:
                            "Up to \(PostLimits.dailyMax) posts a day with photos and macros, plus a Premium mark by your name.",
                        uk: "До \(PostLimits.dailyMax) постів на день з фото й макро та значок Premium біля імені.",
                        ru: "До \(PostLimits.dailyMax) постов в день с фото и макро и значок Premium рядом с именем.",
                        es: "Hasta \(PostLimits.dailyMax) publicaciones al día con fotos y macros, y la marca Premium.")
                )
            }
            .monoCard(padding: 16)
        }
    }

    private func row(symbol: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            MonoIconBox(systemName: symbol, style: .dark, size: 36)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(Tokens.Font.manrope(14, weight: 800))
                    .foregroundStyle(Tokens.Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(text)
                    .font(Tokens.Font.manrope(12, weight: 600))
                    .foregroundStyle(Tokens.Mono.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Tokens.Mono.accent)
        }
    }
}

extension SubscriptionOffering {
    /// "Try 7 days free" when the plan has a trial, otherwise "Go Pro".
    static func paywallCTATitle(for offering: SubscriptionOffering?) -> String {
        if let trialDays = offering?.trialDays {
            return String.localizedStringWithFormat(L("Wypróbuj %lld dni za darmo"), trialDays)
        }
        return L("Przejdź na Pro")
    }

    /// "Then 200 zł / year · cancel anytime" — the price the user commits to.
    var paywallCTACaption: String {
        let price = "\(priceLabel) \(periodLabel)"
        if trialDays != nil {
            return String.localizedStringWithFormat(L("Potem %@ · anuluj kiedy chcesz"), price)
        }
        return String.localizedStringWithFormat(L("%@ · anuluj kiedy chcesz"), price)
    }
}

/// "How the trial works": today full access, day N first charge.
struct PaywallTrialTimeline: View {
    let trialDays: Int
    let offering: SubscriptionOffering

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PaywallSectionTitle(title: L("Jak działa okres próbny"))
            VStack(alignment: .leading, spacing: 0) {
                step(
                    symbol: "lock.open.fill",
                    title: L("Dziś"),
                    text: L("Pełny dostęp do wszystkiego w Pro."),
                    isLast: false)
                step(
                    symbol: "creditcard.fill",
                    title: String.localizedStringWithFormat(L("Dzień %lld"), trialDays),
                    text: String.localizedStringWithFormat(
                        L("Pierwsza płatność: %@. Anulujesz wcześniej — nic nie płacisz."),
                        "\(offering.priceLabel) \(offering.periodLabel)"),
                    isLast: true)
            }
            .monoCard(padding: 16)
        }
    }

    private func step(symbol: String, title: String, text: String, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Tokens.Mono.onHi)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Tokens.Mono.hi))
                if !isLast {
                    Rectangle()
                        .fill(Tokens.Mono.line2)
                        .frame(width: 2, height: 26)
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(Tokens.Font.manrope(14, weight: 800))
                    .foregroundStyle(Tokens.Palette.ink)
                Text(text)
                    .font(Tokens.Font.manrope(12, weight: 600))
                    .foregroundStyle(Tokens.Mono.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 6)
            Spacer(minLength: 0)
        }
    }
}
