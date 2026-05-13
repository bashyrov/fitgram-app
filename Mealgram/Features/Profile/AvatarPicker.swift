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
            Button("Anuluj", role: .cancel) {}
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
            // Soft-fail.
        }
        pickerItem = nil
    }

    private func clearAvatar() {
        store.remove(user.avatarFilename)
        user.avatarFilename = nil
        user.updatedAt = Date()
        try? modelContext.save()
        displayedImage = nil
        Haptics.light()
    }

    private func apply(image: UIImage) {
        do {
            let filename = try store.save(image, previous: user.avatarFilename)
            user.avatarFilename = filename
            user.updatedAt = Date()
            try? modelContext.save()
            displayedImage = image
        } catch {
            // Soft-fail.
        }
    }
}
