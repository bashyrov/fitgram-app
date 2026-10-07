import SafariServices
import SwiftUI

/// Tap-through legal sheet. Holds the Privacy Policy + Terms of Service
/// URLs which are required by Apple's App Store guidelines (5.1.1)
/// and by GDPR / RODO. Defaults point at fitgram.space — change once
/// the actual policy URLs are live.
struct LegalSheet: View {
    let onDismiss: () -> Void

    @State private var presentedURL: IdentifiedURL?
    @Environment(\.openURL) private var openURL

    private struct IdentifiedURL: Identifiable {
        let id = UUID()
        let url: URL
    }

    private static let privacyURL =
        URL(string: "https://fitgram.space/privacy")
        ?? URL(filePath: "/")
    private static let termsURL =
        URL(string: "https://fitgram.space/terms")
        ?? URL(filePath: "/")
    private static let supportEmail = "onefitgram@gmail.com"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    MonoH1(
                        text: L("Wszystko w jednym miejscu"),
                        sub: L("Terms, privacy, contact. Links open in a secure in-app browser.")
                    )
                    documentsCard
                        .padding(.top, 14)
                    sectionHeader(L("Kontakt"))
                    contactCard
                    sectionHeader(L("Atrybucje"))
                    attributionsCard
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.bottom, 34)
            }
            .scrollIndicators(.hidden)
            .background(Tokens.Palette.background.ignoresSafeArea())
            .monoNavigationTitle(L("Prawo i dane"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    MonoNavText(title: closeText, action: onDismiss)
                }
            }
            .sheet(item: $presentedURL) { wrapper in
                SafariView(url: wrapper.url)
                    .ignoresSafeArea()
            }
        }
    }

    /// `sec('', title, '', 22)` — no number, 22 pt top margin.
    private func sectionHeader(_ title: String) -> some View {
        MonoSectionHeader(title: title)
            .padding(.horizontal, 6)
            .padding(.top, 6)
            .padding(.bottom, 12)
    }

    /// rows(): shield "Privacy policy", doc "Terms" with chevrons.
    private var documentsCard: some View {
        VStack(spacing: 0) {
            Button {
                Haptics.light()
                presentedURL = IdentifiedURL(url: Self.privacyURL)
            } label: {
                MonoRow(icon: "shield", title: L("Privacy policy"))
            }
            .buttonStyle(.plain)
            MonoRowDivider()
            Button {
                Haptics.light()
                presentedURL = IdentifiedURL(url: Self.termsURL)
            } label: {
                MonoRow(icon: "doc.text", title: L("Terms"))
            }
            .buttonStyle(.plain)
        }
        .monoRowsCard()
    }

    private var contactCard: some View {
        Button {
            // SFSafariViewController only handles http(s); mail links go to the system handler.
            if let url = URL(string: "mailto:\(Self.supportEmail)") {
                openURL(url)
            }
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                Text(Self.supportEmail)
                    .font(Tokens.Font.manrope(15, weight: 800))
                    .foregroundStyle(Tokens.Palette.ink)
                Text("Odpowiadamy w 24 godziny w dni robocze.")
                    .font(Tokens.Font.manrope(12, weight: 600))
                    .foregroundStyle(Tokens.Mono.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .monoCard(padding: 16)
        }
        .buttonStyle(.plain)
    }

    private var attributionsCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            attribution("Food database: Open Food Facts (ODbL).")
            attribution("Wartości makro: USDA + producent.")
            attribution("Symbole: SF Symbols (Apple).")
            attribution("Tłumaczenia: ChatGPT, weryfikacja: native speakers.")
        }
        .monoCard(padding: 16)
    }

    private func attribution(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(Tokens.Font.manrope(12, weight: 600))
            .foregroundStyle(Tokens.Mono.muted)
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var closeText: String {
        TL(pl: "Zamknij", en: "Close", uk: "Закрити", ru: "Закрыть", es: "Cerrar")
    }
}

/// SFSafariViewController wrapper — opens privacy / terms / mailto in
/// the system in-app browser so the user stays inside Fitgram.
private struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
