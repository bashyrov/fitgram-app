import SwiftUI

/// Preview + share entry point for the streak card. Renders the SwiftUI
/// view to a UIImage on appear so ShareLink has a real PNG attached.
struct StreakSharePreviewSheet: View {
    let streakLength: Int
    let longestLength: Int
    let displayName: String?
    let onDismiss: () -> Void

    @State private var renderedImage: Image?

    var body: some View {
        NavigationStack {
            ZStack {
                Tokens.Palette.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: Tokens.Space.lg) {
                        preview
                        if let renderedImage {
                            ShareLink(
                                item: renderedImage,
                                preview: SharePreview("Mealgram — \(streakLength) dni", image: renderedImage)
                            ) {
                                HStack(spacing: Tokens.Space.sm) {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 17, weight: .semibold))
                                    Text("Udostępnij")
                                        .font(Tokens.Font.bodyEmphasized)
                                }
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Tokens.Space.md)
                                .background(
                                    Capsule().fill(Tokens.Palette.primary)
                                )
                            }
                            .buttonStyle(.plain)
                        } else {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .padding(.vertical, Tokens.Space.lg)
                        }
                    }
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.vertical, Tokens.Space.lg)
                }
            }
            .navigationTitle(Text("Udostępnij serię"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Zamknij", action: onDismiss)
                }
            }
        }
        .task {
            if let uiImage = StreakShareCard.render(
                streakLength: streakLength,
                longestLength: longestLength,
                displayName: displayName
            ) {
                renderedImage = Image(uiImage: uiImage)
            }
        }
    }

    @ViewBuilder
    private var preview: some View {
        if let renderedImage {
            renderedImage
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
                .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 6)
                .padding(.horizontal, Tokens.Space.lg)
        } else {
            RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                .fill(Tokens.Palette.surfaceMuted)
                .aspectRatio(9.0 / 16.0, contentMode: .fit)
                .padding(.horizontal, Tokens.Space.lg)
        }
    }
}
