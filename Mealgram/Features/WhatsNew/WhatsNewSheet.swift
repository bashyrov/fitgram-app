import SwiftUI

/// "Co nowego" sheet shown once after a major version bump. Mealgram
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
            ZStack {
                Tokens.Palette.background.ignoresSafeArea()
                backgroundOrnament
                ScrollView {
                    VStack(spacing: Tokens.Space.lg) {
                        header
                        highlightsList
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.top, Tokens.Space.lg)
                    .padding(.bottom, 100)
                }
                VStack {
                    Spacer()
                    primaryButton
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Później", action: onDismiss)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                }
            }
        }
    }

    private var backgroundOrnament: some View {
        ZStack {
            Circle()
                .fill(Tokens.Palette.primary.opacity(0.20))
                .frame(width: 280, height: 280)
                .blur(radius: 80)
                .offset(x: -160, y: -260)
            Circle()
                .fill(Tokens.Palette.accent.opacity(0.20))
                .frame(width: 320, height: 320)
                .blur(radius: 90)
                .offset(x: 180, y: 320)
        }
        .allowsHitTesting(false)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            HStack(spacing: Tokens.Space.sm) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Tokens.Palette.primary, Tokens.Palette.accent],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                        .shadow(color: Tokens.Palette.primary.opacity(0.35), radius: 12, y: 6)
                    Image(systemName: "sparkles")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Co nowego")
                        .font(Tokens.Font.caption)
                        .textCase(.uppercase)
                        .tracking(1.2)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                    Text("Mealgram \(entry.version)")
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(Tokens.Palette.ink)
                }
                Spacer(minLength: 0)
            }
            Text(entry.headline)
                .font(Tokens.Font.body)
                .foregroundStyle(Tokens.Palette.inkMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var highlightsList: some View {
        VStack(spacing: Tokens.Space.md) {
            ForEach(Array(entry.highlights.enumerated()), id: \.offset) { _, item in
                Card {
                    HStack(alignment: .top, spacing: Tokens.Space.md) {
                        ZStack {
                            Circle()
                                .fill(item.tint.opacity(0.18))
                                .frame(width: 44, height: 44)
                            Image(systemName: item.symbol)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(item.tint)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .font(Tokens.Font.bodyEmphasized)
                                .foregroundStyle(Tokens.Palette.ink)
                            Text(item.body)
                                .font(Tokens.Font.footnote)
                                .foregroundStyle(Tokens.Palette.inkMuted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    private var primaryButton: some View {
        Button(action: {
            Haptics.success()
            onDismiss()
        }) {
            HStack(spacing: 8) {
                Text("Zaczynamy")
                    .font(Tokens.Font.bodyEmphasized)
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Tokens.Space.md)
            .background(
                Capsule().fill(
                    LinearGradient(
                        colors: [Tokens.Palette.primary, Tokens.Palette.accent],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            )
            .shadow(color: Tokens.Palette.primary.opacity(0.4), radius: 14, y: 6)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Tokens.Space.screenPadding)
        .padding(.bottom, Tokens.Space.lg)
    }
}

// MARK: - Catalog

struct WhatsNewEntry: Equatable, Sendable {
    let version: String
    let headline: LocalizedStringKey
    let highlights: [Highlight]

    struct Highlight: Equatable, Sendable {
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
/// MARKETING_VERSION's major or minor digits. Patch-only bumps don't
/// need an entry — the system silently keeps the previously-shown
/// version in sync.
enum WhatsNewCatalog {
    static let all: [WhatsNewEntry] = [
        .init(
            version: "0.1.0",
            headline: "Pierwsze wydanie Mealgrama. Dzięki, że jesteś tu od dnia 1.",
            highlights: [
                .init(
                    symbol: "camera.fill",
                    tint: Tokens.Palette.primary,
                    title: "Skanowanie posiłków zdjęciem",
                    body: "AI rozpoznaje pierogi, schabowy, kasze, zupy — 160+ polskich dań w bazie."
                ),
                .init(
                    symbol: "sparkles.tv",
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
                    tint: Color(red: 0.55, green: 0.45, blue: 0.85),
                    title: "5 języków, mgnienie oka",
                    body: "Polski, English, Українська, Русский, Español — zmiana bez restartu w Ustawieniach."
                ),
                .init(
                    symbol: "applewatch",
                    tint: Tokens.Palette.success,
                    title: "Widżety, Live Activity, Apple Watch",
                    body: "Kalorie na lock screenie, w Dynamic Island i na nadgarstku."
                ),
            ]
        ),
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
