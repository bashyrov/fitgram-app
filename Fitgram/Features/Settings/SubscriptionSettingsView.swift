import StoreKit
import SwiftUI

/// Settings → Subscription: current plan, restore purchases, and Apple's
/// manage-subscription sheet. Free users also get the way into the paywall.
struct SubscriptionSettingsView: View {
    let entitlementsStore: EntitlementsStore
    let paywallCoordinator: PaywallCoordinator

    @State private var isRestoring = false
    @State private var isManagePresented = false
    @State private var restoreResult: String?

    private var snapshot: SubscriptionSnapshot { entitlementsStore.subscription }
    private var isPremium: Bool { entitlementsStore.current.isPremium }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                MonoH1(text: Self.screenTitle, sub: Self.heroSubtitle, kicker: Self.kicker)
                statusCard
                    .padding(.top, 6)
                actionsCard
                    .padding(.top, 16)
                if let restoreResult {
                    MonoHint(text: restoreResult)
                        .padding(.top, 12)
                        .padding(.horizontal, 6)
                }
            }
            .padding(.horizontal, Tokens.Space.screenPadding)
            .padding(.bottom, 34)
        }
        .scrollIndicators(.hidden)
        .background(Tokens.Palette.background.ignoresSafeArea())
        .monoNavigationTitle(Self.screenTitle)
        .manageSubscriptionsSheet(isPresented: $isManagePresented)
        .onChange(of: isManagePresented) { _, isOpen in
            // Cancelling or switching plans happens in Apple's sheet.
            if !isOpen { Task { await entitlementsStore.refresh() } }
        }
    }

    private var statusCard: some View {
        HStack(spacing: 12) {
            MonoIconBox(systemName: isPremium ? "star.fill" : "star", style: .accent, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(isPremium ? "Fitgram Premium" : Self.freePlanTitle)
                    .font(Tokens.Font.manrope(15, weight: 800))
                    .foregroundStyle(Tokens.Palette.ink)
                Text(statusLine)
                    .font(Tokens.Font.manrope(12, weight: 600))
                    .foregroundStyle(Tokens.Mono.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .monoCard(padding: 16)
    }

    private var actionsCard: some View {
        VStack(spacing: 0) {
            if !isPremium {
                Button {
                    paywallCoordinator.present(.manual)
                } label: {
                    MonoRow(icon: "sparkles", title: Self.tryPremiumTitle, sub: Self.tryPremiumSubtitle)
                }
                .buttonStyle(.plain)
                MonoRowDivider()
            }
            Button {
                Task { await restore() }
            } label: {
                MonoRow(icon: "arrow.clockwise", title: Self.restoreTitle, sub: Self.restoreSubtitle) {
                    if isRestoring {
                        ProgressView()
                    } else {
                        MonoChevron()
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(isRestoring)
            MonoRowDivider()
            Button {
                isManagePresented = true
            } label: {
                MonoRow(icon: "creditcard", title: Self.manageTitle, sub: Self.manageSubtitle)
            }
            .buttonStyle(.plain)
        }
        .monoRowsCard()
    }

    private var statusLine: String {
        guard isPremium else { return Self.freePlanSubtitle }
        guard let date = snapshot.expirationDate?.formatted(.dateTime.day().month(.wide).year()) else {
            return Self.activeLine
        }
        if snapshot.isTrial {
            return String(format: Self.trialUntilFormat, date)
        }
        return String(format: snapshot.willRenew ? Self.renewsFormat : Self.endsFormat, date)
    }

    private func restore() async {
        isRestoring = true
        restoreResult = nil
        defer { isRestoring = false }
        do {
            let isActive = try await entitlementsStore.restorePurchases()
            restoreResult = isActive ? Self.restoredMessage : Self.nothingToRestoreMessage
            if isActive { Haptics.success() }
        } catch {
            restoreResult = Self.restoreFailedMessage
        }
    }
}

// MARK: - Copy

extension SubscriptionSettingsView {
    static var screenTitle: String {
        TL(pl: "Subskrypcja", en: "Subscription", uk: "Підписка", ru: "Подписка", es: "Suscripción")
    }

    fileprivate static var kicker: String { "Fitgram Premium" }

    fileprivate static var heroSubtitle: String {
        TL(
            pl: "Twój plan, przywracanie zakupów i zarządzanie subskrypcją w Apple.",
            en: "Your plan, restoring purchases and managing the subscription with Apple.",
            uk: "Твій план, відновлення покупок і керування підпискою в Apple.",
            ru: "Твой план, восстановление покупок и управление подпиской в Apple.",
            es: "Tu plan, restaurar compras y gestionar la suscripción en Apple.")
    }

    fileprivate static var freePlanTitle: String {
        TL(pl: "Plan darmowy", en: "Free plan", uk: "Безкоштовний план", ru: "Бесплатный план", es: "Plan gratuito")
    }

    fileprivate static var freePlanSubtitle: String {
        TL(
            pl: "Podstawowe limity AI", en: "Basic AI limits", uk: "Базові ліміти ШІ", ru: "Базовые лимиты ИИ",
            es: "Límites básicos de IA")
    }

    fileprivate static var activeLine: String {
        TL(pl: "Aktywna", en: "Active", uk: "Активна", ru: "Активна", es: "Activa")
    }

    fileprivate static var renewsFormat: String {
        TL(
            pl: "Aktywna · odnowi się %@", en: "Active · renews on %@", uk: "Активна · поновиться %@",
            ru: "Активна · продлится %@", es: "Activa · se renueva el %@")
    }

    fileprivate static var endsFormat: String {
        TL(
            pl: "Anulowana · aktywna do %@", en: "Cancelled · active until %@", uk: "Скасована · активна до %@",
            ru: "Отменена · активна до %@", es: "Cancelada · activa hasta el %@")
    }

    fileprivate static var trialUntilFormat: String {
        TL(
            pl: "Okres próbny do %@", en: "Free trial until %@", uk: "Пробний період до %@",
            ru: "Пробный период до %@", es: "Prueba gratuita hasta el %@")
    }

    fileprivate static var tryPremiumTitle: String {
        TL(
            pl: "Wypróbuj Premium", en: "Try Premium", uk: "Спробувати Premium", ru: "Попробовать Premium",
            es: "Probar Premium")
    }

    fileprivate static var tryPremiumSubtitle: String {
        TL(
            pl: "7 dni za darmo · duże limity · Ola AI", en: "7 days free · high limits · Ola AI",
            uk: "7 днів безкоштовно · великі ліміти · ШІ-коуч Оля",
            ru: "7 дней бесплатно · большие лимиты · ИИ-коуч Оля", es: "7 días gratis · límites altos · Ola AI")
    }

    fileprivate static var restoreTitle: String {
        TL(
            pl: "Przywróć zakupy", en: "Restore purchases", uk: "Відновити покупки", ru: "Восстановить покупки",
            es: "Restaurar compras")
    }

    fileprivate static var restoreSubtitle: String {
        TL(
            pl: "Po zmianie telefonu lub ponownej instalacji",
            en: "After a new phone or reinstalling the app",
            uk: "Після зміни телефона або перевстановлення",
            ru: "После смены телефона или переустановки",
            es: "Tras cambiar de teléfono o reinstalar")
    }

    fileprivate static var manageTitle: String {
        TL(
            pl: "Zarządzaj subskrypcją Apple", en: "Manage Apple subscription", uk: "Керувати підпискою Apple",
            ru: "Управлять подпиской Apple", es: "Gestionar suscripción de Apple")
    }

    fileprivate static var manageSubtitle: String {
        TL(
            pl: "Zmień plan lub anuluj", en: "Change plan or cancel", uk: "Змінити план або скасувати",
            ru: "Сменить план или отменить", es: "Cambiar de plan o cancelar")
    }

    fileprivate static var restoredMessage: String {
        TL(
            pl: "Subskrypcja przywrócona.", en: "Subscription restored.", uk: "Підписку відновлено.",
            ru: "Подписка восстановлена.", es: "Suscripción restaurada.")
    }

    fileprivate static var nothingToRestoreMessage: String {
        TL(
            pl: "Nie znaleziono aktywnej subskrypcji na tym Apple ID.",
            en: "No active subscription found for this Apple ID.",
            uk: "Активної підписки на цьому Apple ID не знайдено.",
            ru: "Активная подписка на этом Apple ID не найдена.",
            es: "No hay ninguna suscripción activa en este Apple ID.")
    }

    fileprivate static var restoreFailedMessage: String {
        TL(
            pl: "Nie udało się przywrócić zakupów. Spróbuj ponownie.",
            en: "Couldn't restore purchases. Try again.",
            uk: "Не вдалося відновити покупки. Спробуй ще раз.",
            ru: "Не удалось восстановить покупки. Попробуй ещё раз.",
            es: "No se pudieron restaurar las compras. Inténtalo de nuevo.")
    }
}
