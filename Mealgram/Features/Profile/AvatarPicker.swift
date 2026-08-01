import PhotosUI
import SwiftData
import SwiftUI

/// Circle avatar + tap-to-change. Shows the current avatar (if any),
/// or the user's initial as a fallback. Tapping raises a small action
/// sheet so the user can pick between the camera and the photo library.
struct AvatarPicker: View {
    let user: User
    let store: AvatarStore
    var size: CGFloat = 56

    @Environment(\.modelContext) private var modelContext
    @State private var pickerItem: PhotosPickerItem?
    @State private var displayedImage: UIImage?
    @State private var isActionSheetPresented = false
    @State private var isCameraPresented = false
    @State private var isPhotoPickerPresented = false
    @State private var errorMessage: String?

    var body: some View {
        Button {
            isActionSheetPresented = true
        } label: {
            content
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Zmień zdjęcie profilowe"))
        .confirmationDialog(
            "Zmień zdjęcie profilowe",
            isPresented: $isActionSheetPresented,
            titleVisibility: .visible
        ) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Zrób zdjęcie") {
                    isCameraPresented = true
                }
            }
            Button("Wybierz z biblioteki") {
                isPhotoPickerPresented = true
            }
            if user.avatarFilename != nil {
                Button("Usuń zdjęcie", role: .destructive) {
                    clearAvatar()
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .photosPicker(isPresented: $isPhotoPickerPresented, selection: $pickerItem, matching: .images)
        .fullScreenCover(isPresented: $isCameraPresented) {
            CameraImagePicker(
                onPicked: { image in apply(image: image) },
                onDismiss: { isCameraPresented = false }
            )
            .ignoresSafeArea()
        }
        .onAppear(perform: loadCurrent)
        .onChange(of: pickerItem) { _, newValue in
            Task { await handlePicked(item: newValue) }
        }
        .alert(
            avatarErrorTitle,
            isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
        ) {
            Button(okTitle, role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    @ViewBuilder
    private var content: some View {
        if let image = displayedImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            ZStack {
                Circle()
                    .fill(Tokens.Palette.primarySoft)
                    .frame(width: size, height: size)
                Text(initial)
                    .font(size > 50 ? Tokens.Font.title2 : Tokens.Font.bodyEmphasized)
                    .foregroundStyle(Tokens.Palette.primary)
            }
        }
    }

    private var initial: String {
        if let first = user.displayName?.first { return String(first).uppercased() }
        if let first = user.email?.first { return String(first).uppercased() }
        return "M"
    }

    private func loadCurrent() {
        if let filename = user.avatarFilename {
            displayedImage = store.load(filename)
        }
    }

    private func handlePicked(item: PhotosPickerItem?) async {
        guard let item else { return }
        do {
            guard
                let data = try await item.loadTransferable(type: Data.self),
                let image = UIImage(data: data)
            else { return }
            apply(image: image)
        } catch {
            errorMessage = avatarLoadErrorMessage
        }
        pickerItem = nil
    }

    private func clearAvatar() {
        let previousFilename = user.avatarFilename
        let previousImage = displayedImage
        user.avatarFilename = nil
        user.updatedAt = Date()
        do {
            try modelContext.save()
            store.remove(previousFilename)
            displayedImage = nil
            Haptics.light()
        } catch {
            user.avatarFilename = previousFilename
            displayedImage = previousImage
            errorMessage = avatarSaveErrorMessage
        }
    }

    private func apply(image: UIImage) {
        let previousFilename = user.avatarFilename
        let previousImage = displayedImage
        do {
            let filename = try store.save(image, previous: user.avatarFilename)
            user.avatarFilename = filename
            user.updatedAt = Date()
            try modelContext.save()
            displayedImage = image
        } catch {
            user.avatarFilename = previousFilename
            displayedImage = previousImage
            errorMessage = avatarSaveErrorMessage
        }
    }

    private var avatarErrorTitle: String {
        TL(
            pl: "Nie zapisano zdjęcia",
            en: "Photo was not saved",
            uk: "Фото не збережено",
            ru: "Фото не сохранено",
            es: "No se guardó la foto"
        )
    }

    private var avatarLoadErrorMessage: String {
        TL(
            pl: "Nie udało się odczytać tego zdjęcia. Wybierz inne.",
            en: "We could not read this photo. Choose another one.",
            uk: "Не вдалося прочитати це фото. Виберіть інше.",
            ru: "Не удалось прочитать это фото. Выберите другое.",
            es: "No pudimos leer esta foto. Elige otra."
        )
    }

    private var avatarSaveErrorMessage: String {
        TL(
            pl: "Spróbuj ponownie za chwilę.",
            en: "Try again in a moment.",
            uk: "Спробуйте ще раз трохи пізніше.",
            ru: "Попробуйте ещё раз чуть позже.",
            es: "Inténtalo de nuevo en un momento."
        )
    }

    private var okTitle: String {
        TL(pl: "OK", en: "OK", uk: "OK", ru: "OK", es: "OK")
    }
}
