import SwiftUI

/// Static FAQ + contact entry for App Store review compliance. Content
/// hard-coded for now; once we have a CMS / website this can fetch.
struct HelpFAQSheet: View {
    let onDismiss: () -> Void

    private struct FAQItem: Identifiable {
        let id = UUID()
        let question: String
        let answer: String
    }

    private let items: [FAQItem] = [
        FAQItem(
            question: L("How is Fitgram different from other calorie counters?"),
            answer: L(
                "Skupiamy się na spokojnym tempie — Ola podpowiada w tle, "
                    + "a streak + odznaki utrzymują motywację bez surowego liczenia każdej kalorii."
            )
        ),
        FAQItem(
            question: L("Skąd biorą się wartości odżywcze w Szybkiej bazie?"),
            answer: L(
                "Polska baza opiera się na publicznych źródłach USDA + producent "
                    + "(gdzie znamy markę). Kody kreskowe ciągniemy z Open Food Facts."
            )
        ),
        FAQItem(
            question: L("How does AI photo analysis work?"),
            answer: L(
                "Wysyłamy zdjęcie przez nasz proxy do Gemini, które rozpoznaje składniki + szacuje porcje. "
                    + "Nie zostawiamy zdjęcia poza Twoim telefonem ani naszym proxy."
            )
        ),
        FAQItem(
            question: L("Why does the streak reset after one missed day?"),
            answer: L(
                "Streak to nawyk codzienny. Możesz użyć \"freeze\", żeby utrzymać serię "
                    + "(przycisk pojawia się po południu, gdy jeszcze nic nie wpisałeś)."
            )
        ),
        FAQItem(
            question: L("How do I delete my account?"),
            answer: L(
                "Profil → Ustawienia → Konto → Usuń konto. Fitgram usuwa dane z urządzenia "
                    + "i wysyła żądanie usunięcia danych serwerowych. Subskrypcję anulujesz w Apple ID."
            )
        ),
        FAQItem(
            question: L("Fitgram nie poznaje mojego dania — co robić?"),
            answer: L(
                "Stuknij ołówek przy pozycji, którą rozpoznał, i poprawiaj na bieżąco. "
                    + "Twoja kalibracja AI uczy się porcji w czasie. Dodanie ręczne też zawsze działa."
            )
        ),
        FAQItem(
            question: L("Is my data safe?"),
            answer: L(
                "Tak. Wszystko lokalnie w SwiftData. Eksport JSON + CSV w każdej chwili. "
                    + "RODO-zgodnie — nawet bez konta na serwerze, nikt poza Tobą ich nie widzi."
            )
        ),
    ]

    @State private var expanded: Set<Int> = []
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    MonoH1(text: headlineText)
                    faqCard
                        .padding(.top, 14)
                    contactCard
                        .padding(.top, 12)
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.bottom, 34)
            }
            .scrollIndicators(.hidden)
            .background(Tokens.Palette.background.ignoresSafeArea())
            .monoNavigationTitle(titleText)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    MonoNavText(title: closeText, action: onDismiss)
                }
            }
        }
    }

    /// rows(): one question per row with a chevron-down; tapping reveals the answer.
    private var faqCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                if index > 0 {
                    MonoRowDivider(inset: 16)
                }
                qaRow(item, index: index)
            }
        }
        .monoRowsCard()
    }

    private func qaRow(_ item: FAQItem, index: Int) -> some View {
        let isOpen = expanded.contains(index)
        return Button {
            Haptics.selection()
            withAnimation(Tokens.Motion.quick) {
                if isOpen {
                    expanded.remove(index)
                } else {
                    expanded.insert(index)
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                MonoRow(title: item.question) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Tokens.Mono.muted)
                        .rotationEffect(.degrees(isOpen ? 180 : 0))
                }
                if isOpen {
                    Text(item.answer)
                        .font(Tokens.Font.manrope(14, weight: 600))
                        .foregroundStyle(Tokens.Mono.muted)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 14)
                        .padding(.top, -4)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOpen ? .isSelected : [])
    }

    /// card: "Coś jeszcze?" + muted line + outline "Napisz do nas" (mail) 44 pt.
    private var contactCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Anything else?")
                    .font(Tokens.Font.manrope(15, weight: 800))
                    .foregroundStyle(Tokens.Palette.ink)
                Text("Napisz na onefitgram@gmail.com — odpowiadamy w 24 h.")
                    .font(Tokens.Font.manrope(12, weight: 600))
                    .foregroundStyle(Tokens.Mono.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            MonoButton(title: writeToUsText, kind: .outline, icon: "envelope", height: 44) {
                if let url = URL(string: "mailto:onefitgram@gmail.com") {
                    openURL(url)
                }
            }
        }
        .monoCard(padding: 16)
    }

    private var titleText: String {
        TL(pl: "Pomoc", en: "Help", uk: "Допомога", ru: "Помощь", es: "Ayuda")
    }

    private var headlineText: String {
        TL(pl: "Pomoc / FAQ", en: "Help / FAQ", uk: "Допомога / FAQ", ru: "Помощь / FAQ", es: "Ayuda / FAQ")
    }

    private var closeText: String {
        TL(pl: "Zamknij", en: "Close", uk: "Закрити", ru: "Закрыть", es: "Cerrar")
    }

    private var writeToUsText: String {
        TL(pl: "Napisz do nas", en: "Write to us", uk: "Напишіть нам", ru: "Напишите нам", es: "Escríbenos")
    }
}
