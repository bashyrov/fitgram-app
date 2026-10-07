import SwiftUI

/// "Co nowego" sheet shown once after a major version bump. Fitgram
/// compares the currently-running CFBundleShortVersionString against
/// the last version the user saw (stored in UserDefaults). On mismatch
/// — and only for *major* / *minor* bumps, not patch — the sheet
/// surfaces, listing the highlights of what changed. Cosmetic-only,
/// purely informative.
///
/// The matching `WhatsNewContent` catalog lives below — appending a new
/// entry when a future release ships is the entire workflow.
struct WhatsNewSheet: View {
    let entry: WhatsNewEntry
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    highlightsList
                        .padding(.top, 16)
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.bottom, Tokens.Space.lg)
            }
            .background(Tokens.Palette.background.ignoresSafeArea())
            .safeAreaInset(edge: .bottom, spacing: 0) {
                MonoBottomBar {
                    primaryButton
                }
            }
            .monoNavigationTitle(L("Co nowego"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    MonoNavText(title: L("Later"), action: onDismiss)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            MonoH1(
                text: L("Co nowego"),
                sub: String.localizedStringWithFormat(L("Fitgram %@"), entry.version)
            )
            Text(entry.headline)
                .font(Tokens.Font.manrope(14, weight: 600))
                .foregroundStyle(Tokens.Mono.muted)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 6)
        }
    }

    private var highlightsList: some View {
        VStack(spacing: 0) {
            ForEach(Array(entry.highlights.enumerated()), id: \.offset) { index, item in
                if index > 0 {
                    MonoRowDivider()
                }
                HStack(spacing: 12) {
                    MonoIconBox(systemName: item.symbol, style: .dark, size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(Tokens.Font.manrope(15, weight: 800))
                            .foregroundStyle(Tokens.Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(item.body)
                            .font(Tokens.Font.manrope(12, weight: 600))
                            .foregroundStyle(Tokens.Mono.muted)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 13)
                .padding(.horizontal, 16)
                .accessibilityElement(children: .combine)
            }
        }
        .monoRowsCard()
    }

    private var primaryButton: some View {
        MonoButton(title: L("Zaczynamy"), kind: .dark) {
            Haptics.success()
            onDismiss()
        }
    }
}

// MARK: - Catalog

struct WhatsNewEntry: Equatable {
    let version: String
    let headline: LocalizedStringKey
    let highlights: [Highlight]

    struct Highlight: Equatable {
        let symbol: String
        let tint: Color
        let title: LocalizedStringKey
        let body: LocalizedStringKey
    }

    func toIdentifiable() -> IdentifiableWhatsNewEntry {
        IdentifiableWhatsNewEntry(entry: self)
    }
}

/// `.sheet(item:)` needs Identifiable; this thin wrapper supplies a
/// version-keyed id so SwiftUI swaps the sheet correctly when the
/// content changes.
struct IdentifiableWhatsNewEntry: Identifiable, Equatable {
    let entry: WhatsNewEntry
    var id: String { entry.version }
}

/// "What's new" catalog. Append at the top when a release bumps
/// `MARKETING_VERSION`'s major or minor digits. Patch-only bumps don't
/// need an entry — the system silently keeps the previously-shown
/// version in sync.
enum WhatsNewCatalog {
    nonisolated(unsafe) static let all: [WhatsNewEntry] = [
        .init(
            version: "0.1.0",
            headline: "Pierwsze wydanie Fitgrama. Dzięki, że jesteś tu od dnia 1.",
            highlights: [
                .init(
                    symbol: "camera",
                    tint: Tokens.Palette.primary,
                    title: "Skanowanie posiłków zdjęciem",
                    body: "AI rozpoznaje pierogi, schabowy, kasze, zupy — 160+ polskich dań w bazie."
                ),
                .init(
                    symbol: "sparkles",
                    tint: Tokens.Palette.accent,
                    title: "Trener AI Ola",
                    body: "Codzienne podsumowania + 150 ciekawostek o kaloriach, treningu i kuchni polskiej."
                ),
                .init(
                    symbol: "target",
                    tint: Tokens.Palette.warning,
                    title: "Śledzenie celu wagi",
                    body: "Wykres trendu, codzienne wpisy, przypomnienie i wskazówki AI dla Twojego celu."
                ),
                .init(
                    symbol: "globe",
                    tint: Tokens.Palette.lime,
                    title: "5 languages, instant switch",
                    body: "Polski, English, Українська, Русский, Español — zmiana bez restartu w Ustawieniach."
                ),
                .init(
                    symbol: "square.grid.2x2",
                    tint: Tokens.Palette.success,
                    title: "Widżety, Live Activity, Apple Watch",
                    body: "Kalorie na lock screenie, w Dynamic Island i na nadgarstku."
                ),
            ]
        )
    ]

    /// Returns the entry the user should see, or nil if the running
    /// version matches the last-seen one.
    static func entryToPresent(
        runningVersion: String,
        lastSeen: String?
    ) -> WhatsNewEntry? {
        guard runningVersion != lastSeen else { return nil }
        return all.first { $0.version == runningVersion }
    }
}
