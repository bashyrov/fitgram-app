import SwiftUI

/// Raised when the user taps a badge in the Profile grid. Shows the
/// larger glyph, title, longer description, and the earned date if any.
/// Locked badges show the same info plus a "co trzeba zrobić" line.
struct AchievementDetailSheet: View {
    let definition: AchievementDefinition
    let earnedAt: Date?
    let onDismiss: () -> Void

    @State private var renderedImage: Image?
    @State private var renderedUIImage: UIImage?

    private var isEarned: Bool { earnedAt != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    MonoAchievementGlyph(
                        definition: definition, isEarned: isEarned, size: 140, radius: 44, symbolSize: 60
                    )
                    Text(definition.title)
                        .font(Tokens.Font.monoDisplay(30))
                        .textCase(.uppercase)
                        .foregroundStyle(Tokens.Palette.ink)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(definition.summary)
                        .font(Tokens.Font.manrope(14, weight: 600))
                        .foregroundStyle(Tokens.Mono.muted)
                        .lineSpacing(3)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    statusLine
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .padding(.top, 30)
                .padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)
            .background(Tokens.Palette.background.ignoresSafeArea())
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if isEarned, let renderedImage, let renderedUIImage {
                    MonoBottomBar {
                        ShareLink(
                            item: ShareCardImage(image: renderedUIImage, fileName: "fitgram-achievement"),
                            preview: SharePreview(
                                "Fitgram — \(definition.title)",
                                image: renderedImage
                            )
                        ) {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 15, weight: .bold))
                                Text("Udostępnij odznakę")
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(MonoButtonStyle(kind: .dark))
                    }
                }
            }
            .task(id: definition.id) {
                guard isEarned else { return }
                if let uiImage = AchievementShareCard.render(definition: definition, earnedAt: earnedAt) {
                    renderedUIImage = uiImage
                    renderedImage = Image(uiImage: uiImage)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    MonoNavText(title: L("Close"), action: onDismiss)
                }
            }
        }
    }

    /// 30 pt track pill: "Zdobyte <date>" or "Jeszcze niezdobyte".
    private var statusLine: some View {
        Group {
            if let earnedAt {
                Text(String.localizedStringWithFormat(L("Zdobyte %@"), Self.dateFormatter.string(from: earnedAt)))
                    .foregroundStyle(Tokens.Palette.ink)
            } else {
                Text("Jeszcze niezdobyte")
                    .foregroundStyle(Tokens.Mono.muted)
            }
        }
        .font(Tokens.Font.manrope(13, weight: 800))
        .lineLimit(1)
        .padding(.horizontal, 12)
        .frame(height: 30)
        .background(Capsule().fill(Tokens.Mono.track))
    }

    private static var dateFormatter: DateFormatter {

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: LocalizationStore.currentLanguageCode())
        formatter.dateFormat = "d MMMM yyyy"
        return formatter

    }
}
