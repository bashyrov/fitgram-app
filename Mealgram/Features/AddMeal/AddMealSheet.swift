import SwiftUI

/// Branded add-meal picker. Replaces the stock iOS confirmation dialog
/// with six rich cards — colored icon chip + title + subtitle + per-option
/// quota chip when the feature is gated. Detents let the user drag the
/// sheet up to full screen, or dismiss with a swipe.
struct AddMealSheet: View {
    let entitlementsStore: EntitlementsStore
    let usageMeter: UsageMeter
    let onPhotoScan: () -> Void
    let onBarcode: () -> Void
    let onQuickDB: () -> Void
    let onVoice: () -> Void
    let onRecipe: () -> Void
    let onManual: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(spacing: Tokens.Space.sm) {
                    photoRow
                    barcodeRow
                    voiceRow
                    quickDBRow
                    recipeRow
                    manualRow
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.bottom, Tokens.Space.lg)
            }
            cancelBar
        }
        .background(Tokens.Palette.background.ignoresSafeArea())
        .presentationDetents([.height(640), .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(Tokens.Radius.xxl)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 4) {
            Text("Co dodajesz?")
                .font(Tokens.Font.title2)
                .foregroundStyle(Tokens.Palette.ink)
            Text("Wybierz najszybszy sposób na ten posiłek")
                .font(Tokens.Font.footnote)
                .foregroundStyle(Tokens.Palette.inkMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Tokens.Space.lg)
        .padding(.bottom, Tokens.Space.md)
    }

    // MARK: - Rows

    private var photoRow: some View {
        AddMealRow(
            emoji: "📸",
            iconTint: Tokens.Palette.primary,
            title: "Zdjęcie posiłku",
            subtitle: "AI rozpozna składniki w 5 sekund",
            quota: quotaLabel(
                used: usageMeter.used(.photoScan),
                cap: entitlementsStore.current.photoScansPerWeek
            ),
            action: onPhotoScan
        )
    }

    private var barcodeRow: some View {
        AddMealRow(
            emoji: "📦",
            iconTint: Tokens.Palette.accent,
            title: "Kod kreskowy",
            subtitle: "Open Food Facts · prosto z opakowania",
            quota: quotaLabel(
                used: usageMeter.used(.barcodeScan),
                cap: entitlementsStore.current.barcodeScansPerWeek
            ),
            action: onBarcode
        )
    }

    private var voiceRow: some View {
        AddMealRow(
            emoji: "🎙",
            iconTint: Tokens.Palette.warning,
            title: "Powiedz na głos",
            subtitle: "„schabowy 200 gram 400 kcal”",
            quota: quotaLabel(
                used: usageMeter.used(.voiceEntry),
                cap: entitlementsStore.current.voiceEntriesPerWeek
            ),
            action: onVoice
        )
    }

    private var quickDBRow: some View {
        AddMealRow(
            emoji: "🔎",
            iconTint: Tokens.Palette.success,
            title: "Szybka baza",
            subtitle: "160+ polskich potraw · bez limitu",
            quota: .unlimited,
            action: onQuickDB
        )
    }

    private var recipeRow: some View {
        AddMealRow(
            emoji: "📖",
            iconTint: Color(red: 0.45, green: 0.55, blue: 0.90),
            title: "Mój przepis",
            subtitle: "Z Twojej książki kucharskiej",
            quota: .unlimited,
            action: onRecipe
        )
    }

    private var manualRow: some View {
        AddMealRow(
            emoji: "✍️",
            iconTint: Tokens.Palette.ink,
            title: "Wpisz ręcznie",
            subtitle: "Sam wpisz kalorie + makro",
            quota: .unlimited,
            action: onManual
        )
    }

    // MARK: - Cancel

    private var cancelBar: some View {
        Button(action: onCancel) {
            Text("Anuluj")
                .font(Tokens.Font.bodyEmphasized)
                .foregroundStyle(Tokens.Palette.inkMuted)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: Tokens.Radius.pill, style: .continuous)
                        .fill(Tokens.Palette.surfaceMuted)
                )
        }
        .buttonStyle(PressableButtonStyle())
        .padding(.horizontal, Tokens.Space.screenPadding)
        .padding(.bottom, Tokens.Space.lg)
    }

    // MARK: - Quota helpers

    private func quotaLabel(used: Int, cap: Int?) -> AddMealRow.Quota {
        guard let cap else { return .unlimited }
        return .ofWeek(used: used, cap: cap)
    }
}

/// Single row in the add-meal sheet — coloured emoji puck + title +
/// subtitle + optional quota chip on the trailing edge.
private struct AddMealRow: View {
    enum Quota {
        case unlimited
        case ofWeek(used: Int, cap: Int)

        var label: String? {
            switch self {
            case .unlimited: return nil
            case .ofWeek(let used, let cap):
                return "\(max(0, cap - used)) / \(cap)"
            }
        }

        var isExhausted: Bool {
            if case .ofWeek(let used, let cap) = self { return used >= cap }
            return false
        }
    }

    let emoji: String
    let iconTint: Color
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let quota: Quota
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Tokens.Space.md) {
                ZStack {
                    Circle()
                        .fill(iconTint.opacity(0.18))
                        .frame(width: 52, height: 52)
                    Text(emoji)
                        .font(.system(size: 26))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Tokens.Font.bodyEmphasized)
                        .foregroundStyle(Tokens.Palette.ink)
                    Text(subtitle)
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                quotaChip
            }
            .padding(Tokens.Space.md)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                    .fill(Tokens.Palette.surface)
                    .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
            )
        }
        .buttonStyle(PressableButtonStyle())
    }

    @ViewBuilder
    private var quotaChip: some View {
        if let label = quota.label {
            HStack(spacing: 4) {
                if quota.isExhausted {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10, weight: .bold))
                }
                Text(label)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(quota.isExhausted
                        ? Tokens.Palette.error.opacity(0.18)
                        : Tokens.Palette.primary.opacity(0.15))
            )
            .foregroundStyle(quota.isExhausted ? Tokens.Palette.error : Tokens.Palette.primary)
        } else {
            Image(systemName: "infinity")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Tokens.Palette.inkSubtle)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(Tokens.Palette.surfaceMuted)
                )
        }
    }
}
