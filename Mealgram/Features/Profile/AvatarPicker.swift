import PhotosUI
import SwiftData
import SwiftUI

/// Circle avatar + tap-to-change via PhotosPicker. Shows the current
/// avatar (if any), or the user's initial as a fallback.
struct AvatarPicker: View {
    let user: User
    let store: AvatarStore
    var size: CGFloat = 56

    @Environment(\.modelContext) private var modelContext
    @State private var pickerItem: PhotosPickerItem?
    @State private var displayedImage: UIImage?

    var body: some View {
        PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
            content
        }
        .onAppear(perform: loadCurrent)
        .onChange(of: pickerItem) { _, newValue in
            Task { await handlePicked(item: newValue) }
        }
        .accessibilityLabel(Text("Zmień zdjęcie profilowe"))
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
            let filename = try store.save(image, previous: user.avatarFilename)
            user.avatarFilename = filename
            user.updatedAt = Date()
            try? modelContext.save()
            displayedImage = image
        } catch {
            // Soft-fail: no toast for now; cap at log.
        }
        pickerItem = nil
    }
}
