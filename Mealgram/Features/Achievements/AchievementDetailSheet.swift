import SwiftUI

/// Raised when the user taps a badge in the Profile grid. Shows the
/// larger glyph, title, longer description, and the earned date if any.
/// Locked badges show the same info plus a "co trzeba zrobić" line.
struct AchievementDetailSheet: View {
    let definition: AchievementDefinition
    let earnedAt: Date?
    let onDismiss: () -> Void

    @State private var renderedImage: Image?

    private var isEarned: Bool { earnedAt != nil }

    var body: some View {
        NavigationStack {
            ZStack {
                Tokens.Palette.background.ignoresSafeArea()
                VStack(spacing: Tokens.Space.lg) {
                    badge
                    Text(definition.title)
                        .font(Tokens.Font.title3)
                        .foregroundStyle(Tokens.Palette.ink)
                    Text(definition.summary)
                        .font(Tokens.Font.body)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    statusLine
                    if isEarned, let renderedImage {
                        ShareLink(
                            item: renderedImage,
                            preview: SharePreview(
                                "Mealgram — \(definition.title)",
                                image: renderedImage
                            )
                        ) {
                            HStack(spacing: Tokens.Space.sm) {
                                Image(systemName: "square.and.arrow.up")
                                Text("Udostępnij odznakę")
                                    .font(Tokens.Font.bodyEmphasized)
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Tokens.Space.md)
                            .background(Capsule().fill(Tokens.Palette.primary))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, Tokens.Space.lg)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.vertical, Tokens.Space.lg)
            }
            .task(id: definition.id) {
                guard isEarned else { return }
                if let uiImage = AchievementShareCard.render(
                    definition: definition,
                    earnedAt: earnedAt,
                    displayName: nil
                ) {
                    renderedImage = Image(uiImage: uiImage)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", action: onDismiss)
                }
            }
        }
    }

    private var badge: some View {
        AchievementMedallion(definition: definition, isEarned: isEarned, size: 136)
    }

    @ViewBuilder
    private var statusLine: some View {
        if let earnedAt {
            Text(String.localizedStringWithFormat(L("Zdobyte %@"), Self.dateFormatter.string(from: earnedAt)))
                .font(Tokens.Font.subheadline)
                .foregroundStyle(Tokens.Palette.primary)
        } else {
            Text("Jeszcze niezdobyte")
                .font(Tokens.Font.subheadline)
                .foregroundStyle(Tokens.Palette.inkMuted)
        }
    }

    private static var dateFormatter: DateFormatter {

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: LocalizationStore.currentLanguageCode())
        formatter.dateFormat = "d MMMM yyyy"
        return formatter

    }
}
