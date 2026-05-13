import SafariServices
import SwiftUI

/// Tap-through legal sheet. Holds the Privacy Policy + Terms of Service
/// URLs which are required by Apple's App Store guidelines (5.1.1)
/// and by GDPR / RODO. Defaults point at mealgram.pl — change once
/// the actual policy URLs are live.
struct LegalSheet: View {
    let onDismiss: () -> Void

    @State private var presentedURL: IdentifiedURL?

    private struct IdentifiedURL: Identifiable {
        let id = UUID()
        let url: URL
    }

    private static let privacyURL =
        URL(string: "https://mealgram.pl/privacy")
        ?? URL(filePath: "/")
    private static let termsURL =
        URL(string: "https://mealgram.pl/terms")
        ?? URL(filePath: "/")
    private static let supportEmail = "hello@mealgram.pl"

    var body: some View {
        NavigationStack {
            ZStack {
                Tokens.Palette.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: Tokens.Space.lg) {
                        intro
                        documentsCard
                        contactCard
                        attributionsCard
                    }
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.vertical, Tokens.Space.lg)
                }
            }
            .navigationTitle(Text("Prawo i dane"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Zamknij", action: onDismiss)
                }
            }
            .sheet(item: $presentedURL) { wrapper in
                SafariView(url: wrapper.url)
                    .ignoresSafeArea()
            }
        }
    }

    private var intro: some View {
        Card(background: Tokens.Palette.primarySoft) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Wszystko w jednym miejscu")
                    .font(Tokens.Font.bodyEmphasized)
                    .foregroundStyle(Tokens.Palette.ink)
                Text("Zasady, prywatność, kontakt. Linki otwierają się w bezpiecznej przeglądarce w aplikacji.")
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var documentsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 0) {
                row(symbol: "lock.shield", title: "Polityka prywatności") {
                    presentedURL = IdentifiedURL(url: Self.privacyURL)
                }
                Divider().background(Tokens.Palette.separator)
                row(symbol: "doc.text", title: "Regulamin") {
                    presentedURL = IdentifiedURL(url: Self.termsURL)
                }
            }
        }
    }

    private var contactCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                Text("Kontakt")
                    .font(Tokens.Font.headline)
                    .foregroundStyle(Tokens.Palette.ink)
                Text("hello@mealgram.pl")
                    .font(Tokens.Font.body)
                    .foregroundStyle(Tokens.Palette.primary)
                    .onTapGesture {
                        if let url = URL(string: "mailto:\(Self.supportEmail)") {
                            presentedURL = IdentifiedURL(url: url)
                        }
                    }
                Text("Odpowiadamy w 24 godziny w dni robocze.")
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Palette.inkSubtle)
            }
        }
    }

    private var attributionsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                Text("Atrybucje")
                    .font(Tokens.Font.headline)
                    .foregroundStyle(Tokens.Palette.ink)
                Text("Baza produktów: Open Food Facts (ODbL).")
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                Text("Wartości makro: USDA + producent.")
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                Text("Symbole: SF Symbols (Apple).")
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                Text("Tłumaczenia: ChatGPT, weryfikacja: native speakers.")
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)
            }
        }
    }

    private func row(symbol: String, title: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Tokens.Space.md) {
                Image(systemName: symbol)
                    .frame(width: 22)
                    .foregroundStyle(Tokens.Palette.primary)
                Text(title)
                    .font(Tokens.Font.body)
                    .foregroundStyle(Tokens.Palette.ink)
                Spacer()
                Image(systemName: "arrow.up.right.square")
                    .foregroundStyle(Tokens.Palette.inkSubtle)
            }
            .padding(.vertical, Tokens.Space.sm)
        }
        .buttonStyle(.plain)
    }
}

/// SFSafariViewController wrapper — opens privacy / terms / mailto in
/// the system in-app browser so the user stays inside Mealgram.
private struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
