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
            question: "Czym Mealgram różni się od innych liczników kalorii?",
            answer: """
                Skupiamy się na spokojnym tempie — Ola podpowiada w tle, a streak \
                + odznaki utrzymują motywację bez surowego liczenia każdej kalorii.
                """
        ),
        FAQItem(
            question: "Skąd biorą się wartości odżywcze w Szybkiej bazie?",
            answer: """
                Polska baza (78+ pozycji) opiera się na publicznych źródłach \
                USDA + producent (gdzie znamy markę). Kody kreskowe ciągniemy z \
                Open Food Facts.
                """
        ),
        FAQItem(
            question: "Jak działa ocena AI ze zdjęcia?",
            answer: """
                Wysyłamy zdjęcie przez nasz proxy do Gemini, które rozpoznaje \
                składniki + szacuje porcje. Nigdy nie zostawiamy zdjęcia poza \
                Twoim telefonem ani naszym proxy — bez handlu z firmami trzecimi.
                """
        ),
        FAQItem(
            question: "Dlaczego streak resetuje się po jednym dniu przerwy?",
            answer: """
                Streak to nawyk codzienny. Możesz użyć "freeze", żeby utrzymać \
                serię (przycisk pojawia się po południu, gdy jeszcze nic nie \
                wpisałeś). Freeze odnawiają się co tydzień.
                """
        ),
        FAQItem(
            question: "Jak usunąć konto?",
            answer: """
                Profil → Konto → Usuń konto. Wszystkie lokalne dane znikają \
                natychmiast; serwerowe (gdy ruszy backend) — w ciągu 72 godzin.
                """
        ),
        FAQItem(
            question: "Mealgram nie poznaje mojego dania — co robić?",
            answer: """
                Stuknij ołówek przy pozycji, którą rozpoznał, i poprawiaj na \
                bieżąco. Twoja kalibracja AI uczy się porcji w czasie. \
                Dodanie ręczne też zawsze działa.
                """
        ),
        FAQItem(
            question: "Czy moje dane są bezpieczne?",
            answer: """
                Tak. Wszystko lokalnie w SwiftData. Eksport JSON + CSV w \
                każdej chwili (Profil → Twoje dane). RODO-zgodnie — nawet \
                bez konta na serwerze, nikt poza Tobą ich nie widzi.
                """
        ),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Tokens.Palette.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: Tokens.Space.md) {
                        ForEach(items) { item in
                            qaCard(item)
                        }
                        contactCard
                    }
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.vertical, Tokens.Space.lg)
                }
            }
            .navigationTitle(Text("Pomoc"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Zamknij", action: onDismiss)
                }
            }
        }
    }

    private func qaCard(_ item: FAQItem) -> some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                Text(item.question)
                    .font(Tokens.Font.bodyEmphasized)
                    .foregroundStyle(Tokens.Palette.ink)
                Text(item.answer)
                    .font(Tokens.Font.body)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var contactCard: some View {
        Card(background: Tokens.Palette.primarySoft) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Coś jeszcze?")
                    .font(Tokens.Font.bodyEmphasized)
                    .foregroundStyle(Tokens.Palette.ink)
                Text("Napisz na hello@mealgram.pl — odpowiadamy w 24 h.")
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)
            }
        }
    }
}
