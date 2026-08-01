import PhotosUI
import SwiftUI

/// Preview + share entry point for the streak card. Lets the user pick
/// between the brand gradient, a transparent PNG (for Stories overlays),
/// or any photo from their library that the streak design sits on top of.
struct StreakSharePreviewSheet: View {
    let streakLength: Int
    let longestLength: Int
    let displayName: String?
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
            ZStack {
                Tokens.Palette.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: Tokens.Space.lg) {
                        preview
                        backgroundPicker
                        if backgroundChoice == .photo {
                            photoPickerControl
                        }
                        actions
                    }
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.vertical, Tokens.Space.lg)
                }
            }
            .navigationTitle(Text("Share streak"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", action: onDismiss)
                }
            }
        }
        .task { rerender() }
        .onChange(of: backgroundChoice) { _, _ in rerender() }
        .onChange(of: pickedPhotoItem) { _, item in loadPhoto(from: item) }
        .onChange(of: pickedPhoto) { _, _ in rerender() }
    }

    // MARK: - Sections

    @ViewBuilder
    private var preview: some View {
        let backgroundContent: Color = backgroundChoice == .transparent
            ? Tokens.Palette.surfaceMuted
            : .clear
        ZStack {
            Rectangle()
                .fill(backgroundContent)
            if let renderedImage {
                renderedImage
                    .resizable()
                    .scaledToFit()
            } else {
                ProgressView()
                    .progressViewStyle(.circular)
            }
        }
        .aspectRatio(9.0 / 16.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 6)
        .padding(.horizontal, Tokens.Space.lg)
    }

    private var backgroundPicker: some View {
        Picker(selection: $backgroundChoice) {
            Text("Gradient").tag(BackgroundChoice.gradient)
            Text("Transparent").tag(BackgroundChoice.transparent)
            Text("Photo").tag(BackgroundChoice.photo)
        } label: {
            Text("Background")
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, Tokens.Space.lg)
    }

    private var photoPickerControl: some View {
        PhotosPicker(selection: $pickedPhotoItem, matching: .images, photoLibrary: .shared()) {
            HStack(spacing: Tokens.Space.sm) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 17, weight: .semibold))
                Text(pickedPhoto == nil ? L("Choose photo") : L("Change photo"))
                    .font(Tokens.Font.bodyEmphasized)
            }
            .foregroundStyle(Tokens.Palette.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Tokens.Space.md)
            .background(
                Capsule().fill(Tokens.Palette.primarySoft)
            )
            .padding(.horizontal, Tokens.Space.lg)
        }
    }

    @ViewBuilder
    private var actions: some View {
        if let renderedImage, let renderedUIImage {
            VStack(spacing: Tokens.Space.sm) {
                ShareLink(
                    item: renderedImage,
                    preview: SharePreview(
                        String.localizedStringWithFormat(L("Mealgram — %lld days"), streakLength),
                        image: renderedImage
                    )
                ) {
                    primaryButton(title: L("Share"), symbol: "square.and.arrow.up")
                }
                .buttonStyle(.plain)

                Button {
                    UIImageWriteToSavedPhotosAlbum(renderedUIImage, nil, nil, nil)
                    Haptics.success()
                } label: {
                    secondaryButton(title: L("Save to photos"), symbol: "square.and.arrow.down")
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Tokens.Space.lg)
        }
    }

    private func primaryButton(title: String, symbol: String) -> some View {
        HStack(spacing: Tokens.Space.sm) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
            Text(title).font(Tokens.Font.bodyEmphasized)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, Tokens.Space.md)
        .background(Capsule().fill(Tokens.Palette.primary))
    }

    private func secondaryButton(title: String, symbol: String) -> some View {
        HStack(spacing: Tokens.Space.sm) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
            Text(title).font(Tokens.Font.callout)
        }
        .foregroundStyle(Tokens.Palette.primary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, Tokens.Space.sm)
        .background(
            Capsule().strokeBorder(Tokens.Palette.primary, lineWidth: 1.5)
        )
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
                displayName: displayName,
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
