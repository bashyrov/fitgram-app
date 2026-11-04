import SwiftUI

/// "Free vs Pro" table: header row + hairline-separated feature rows.
struct PaywallComparisonSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PaywallSectionTitle(title: L("Free vs Pro"))
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Color.clear.frame(maxWidth: .infinity, maxHeight: 1)
                    MonoLabel(text: L("Free"))
                        .frame(width: columnWidth)
                    MonoLabel(text: L("Pro"))
                        .frame(width: columnWidth)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                comparisonRow(title: aiActionsTitle, free: aiActionsFree, pro: L("Duże limity"))
                comparisonRow(title: L("Porady Oli"), free: L("Nie"), pro: L("Pełny dostęp"))
                comparisonRow(title: L("Przepisy"), free: "\(FreeTierLimits.savedRecipes ?? 0)", pro: L("Duże limity"))
            }
            .monoRowsCard()
        }
    }

    private let columnWidth: CGFloat = 84

    private var aiActionsTitle: String {
        TL(pl: "Działania AI", en: "AI actions", uk: "Дії ШІ", ru: "ИИ-действия", es: "Acciones de IA")
    }

    /// The free pool is weekly and shared by every AI action.
    private var aiActionsFree: String {
        let cap = FreeTierLimits.aiActionsPerWeek ?? 0
        return TL(
            pl: "\(cap) / tydzień", en: "\(cap) / week", uk: "\(cap) / тиждень",
            ru: "\(cap) / неделя", es: "\(cap) / semana")
    }

    private func comparisonRow(
        title: String,
        free: String,
        pro: String
    ) -> some View {
        HStack(spacing: 0) {
            Text(title)
                .foregroundStyle(Tokens.Palette.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(free)
                .foregroundStyle(Tokens.Mono.muted)
                .multilineTextAlignment(.center)
                .frame(width: columnWidth)
            Text(pro)
                .font(Tokens.Font.manrope(13, weight: 800))
                .foregroundStyle(Tokens.Palette.ink)
                .multilineTextAlignment(.center)
                .frame(width: columnWidth)
        }
        .font(Tokens.Font.manrope(13, weight: 700))
        .lineLimit(2)
        .minimumScaleFactor(0.8)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .overlay(alignment: .top) {
            Rectangle().fill(Tokens.Mono.line).frame(height: 1)
        }
    }
}

struct PaywallTrustSection: View {
    var body: some View {
        HStack(spacing: Tokens.Space.sm) {
            trustPill(symbol: "lock.shield.fill", text: "Apple Pay")
            trustPill(symbol: "arrow.uturn.backward.circle.fill", text: "Anuluj kiedy chcesz")
            trustPill(symbol: "checkmark.seal.fill", text: "7 dni testu")
        }
    }

    private func trustPill(symbol: String, text: LocalizedStringKey) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .bold))
            Text(text)
                .font(Tokens.Font.caption2.weight(.bold))
                .lineLimit(2)
                .minimumScaleFactor(0.75)
        }
        .foregroundStyle(Tokens.Palette.inkMuted)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Capsule().fill(Tokens.Mono.track))
    }
}

/// Shown when StoreKit returned no plans. Prices only ever come from the App
/// Store, so the paywall offers a retry instead of showing hard-coded ones.
struct PaywallPlansUnavailableCard: View {
    let onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                MonoIconBox(systemName: "wifi.exclamationmark", style: .dark, size: 36)
                Text(
                    TL(
                        pl: "Nie udało się załadować planów",
                        en: "Couldn't load the plans",
                        uk: "Не вдалося завантажити плани",
                        ru: "Не удалось загрузить планы",
                        es: "No se pudieron cargar los planes"
                    )
                )
                .font(Tokens.Font.manrope(14, weight: 800))
                .foregroundStyle(Tokens.Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            }
            Text(
                TL(
                    pl: "Sprawdź połączenie z internetem i spróbuj ponownie. Nic nie zostało pobrane.",
                    en: "Check your internet connection and try again. You haven't been charged.",
                    uk: "Перевір з'єднання з інтернетом і спробуй ще раз. Кошти не списано.",
                    ru: "Проверь подключение к интернету и попробуй ещё раз. Деньги не списаны.",
                    es: "Comprueba tu conexión a internet e inténtalo de nuevo. No se te ha cobrado nada."
                )
            )
            .font(Tokens.Font.manrope(12, weight: 600))
            .foregroundStyle(Tokens.Mono.muted)
            .fixedSize(horizontal: false, vertical: true)
            MonoButton(
                title: TL(
                    pl: "Spróbuj ponownie",
                    en: "Try again",
                    uk: "Спробувати ще раз",
                    ru: "Попробовать ещё раз",
                    es: "Reintentar"
                ),
                kind: .outline,
                height: 44,
                action: onRetry
            )
        }
        .monoCard(padding: 16)
    }
}

struct PaywallErrorCard: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Tokens.Mono.danger)
            VStack(alignment: .leading, spacing: 2) {
                Text("Płatność chwilowo nie odpowiada")
                    .font(Tokens.Font.manrope(14, weight: 800))
                    .foregroundStyle(Tokens.Palette.ink)
                Text(message)
                    .font(Tokens.Font.manrope(12, weight: 600))
                    .foregroundStyle(Tokens.Mono.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .monoCard(padding: 16)
    }
}
