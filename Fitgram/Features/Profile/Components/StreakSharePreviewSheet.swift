import PhotosUI
import SwiftUI

/// Preview + share entry point for the streak card. Lets the user pick
/// between the brand gradient, a transparent PNG (for Stories overlays),
/// or any photo from their library that the streak design sits on top of.
struct StreakSharePreviewSheet: View {
    let streakLength: Int
    let longestLength: Int
    let onDismiss: () -> Void

    @State private var renderedImage: Image?
    @State private var renderedUIImage: UIImage?
    @State private var backgroundChoice: BackgroundChoice = .gradient
    @State private var pickedPhotoItem: PhotosPickerItem?
    @State private var pickedPhoto: UIImage?

    private enum BackgroundChoice: String, CaseIterable, Identifiable {
        case gradient
        case transparent
        case photo
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    preview
                        .padding(.horizontal, 48)
                        .padding(.top, 10)
                    backgroundCard
                        .padding(.top, 14)
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)
            .background(Tokens.Palette.background.ignoresSafeArea())
            .safeAreaInset(edge: .bottom, spacing: 0) {
                actions
            }
            .monoNavigationTitle(titleText)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    MonoNavText(title: closeText, action: onDismiss)
                }
            }
        }
        .task { rerender() }
        .onChange(of: backgroundChoice) { _, _ in rerender() }
        .onChange(of: pickedPhotoItem) { _, item in loadPhoto(from: item) }
        .onChange(of: pickedPhoto) { _, _ in rerender() }
    }

    // MARK: - Sections

    /// 9:16 story preview, radius 28 like the mockup card.
    private var preview: some View {
        ZStack {
            Rectangle()
                .fill(backgroundChoice == .transparent ? Color(white: 0.55) : Tokens.Mono.hero)
            if let renderedImage {
                renderedImage
                    .resizable()
                    .scaledToFit()
            } else {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(Tokens.Mono.onHero)
            }
        }
        .aspectRatio(9.0 / 16.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    /// card: LBL "Tło" + seg(Gradient / Transparent / Photo) (+ photo picker when needed).
    private var backgroundCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            MonoLabel(text: L("Background"))
            MonoSegmented(
                selection: $backgroundChoice,
                options: [
                    (value: BackgroundChoice.gradient, title: L("Gradient")),
                    (value: BackgroundChoice.transparent, title: L("Transparent")),
                    (value: BackgroundChoice.photo, title: L("Photo")),
                ]
            )
            if backgroundChoice == .photo {
                photoPickerControl
            }
        }
        .monoCard(padding: 16)
    }

    private var photoPickerControl: some View {
        let title = pickedPhoto == nil ? L("Choose photo") : L("Change photo")
        return PhotosPicker(selection: $pickedPhotoItem, matching: .images, photoLibrary: .shared()) {
            HStack(spacing: 8) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 15, weight: .bold))
                Text(title)
                    .lineLimit(1)
            }
        }
        .buttonStyle(MonoButtonStyle(kind: .outline, height: 44))
    }

    /// bottom(): Share (dark) + Save to photos (outline), side by side, 50 pt.
    @ViewBuilder
    private var actions: some View {
        if let renderedImage, let renderedUIImage {
            MonoBottomBar {
                HStack(spacing: 8) {
                    ShareLink(
                        item: ShareCardImage(image: renderedUIImage),
                        preview: SharePreview("Fitgram — \(streakLength) day streak", image: renderedImage)
                    ) {
                        buttonLabel(title: L("Share"), symbol: "square.and.arrow.up")
                    }
                    .buttonStyle(MonoButtonStyle(kind: .dark, height: 50))

                    Button {
                        Task {
                            if await ShareCardImage(image: renderedUIImage).saveToPhotos() {
                                Haptics.success()
                            } else {
                                Haptics.warning()
                            }
                        }
                    } label: {
                        buttonLabel(title: L("Save to photos"), symbol: "square.and.arrow.down")
                    }
                    .buttonStyle(MonoButtonStyle(kind: .outline, height: 50))
                }
            }
        }
    }

    private func buttonLabel(title: String, symbol: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .bold))
            Text(title)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }

    private var titleText: String {
        TL(
            pl: "Udostępnij serię", en: "Share streak", uk: "Поділитися серією", ru: "Поделиться серией",
            es: "Compartir racha"
        )
    }

    private var closeText: String {
        TL(pl: "Zamknij", en: "Close", uk: "Закрити", ru: "Закрыть", es: "Cerrar")
    }

    // MARK: - Helpers

    private var resolvedBackground: StreakShareCard.Background {
        switch backgroundChoice {
        case .gradient: return .gradient
        case .transparent: return .transparent
        case .photo:
            if let pickedPhoto { return .photo(pickedPhoto) }
            return .transparent
        }
    }

    private func rerender() {
        Task { @MainActor in
            if let img = StreakShareCard.render(
                streakLength: streakLength,
                longestLength: longestLength,
                background: resolvedBackground
            ) {
                renderedUIImage = img
                renderedImage = Image(uiImage: img)
            }
        }
    }

    private func loadPhoto(from item: PhotosPickerItem?) {
        guard let item else { return }
        Task { @MainActor in
            if let data = try? await item.loadTransferable(type: Data.self),
                let uiImage = UIImage(data: data)
            {
                pickedPhoto = uiImage
            }
        }
    }
}
