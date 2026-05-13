import SwiftUI

// swiftlint:disable type_body_length

/// Inspect-and-edit sheet for a saved meal. Lets the user nudge the
/// portion multiplier or delete the meal outright. Item-level edits live
/// in the scan flow and stay there — this surface is intentionally light.
struct MealDetailSheet: View {
    let meal: MealEntry
    let repository: MealRepository
    let photoStore: MealPhotoStore?
    let onDismiss: () -> Void
    let onChanged: () -> Void
    var onDeleted: ((MealEntrySnapshot) -> Void)?

    @State private var portion: Double
    @State private var isConfirmingDelete = false
    @State private var errorMessage: String?
    @State private var tags: [String]
    @State private var newTag: String = ""
    @State private var notes: String
    @State private var zoomedPhoto: ZoomedPhoto?

    private struct ZoomedPhoto: Identifiable {
        let id = UUID()
        let image: UIImage
    }

    init(
        meal: MealEntry,
        repository: MealRepository,
        photoStore: MealPhotoStore? = nil,
        onDismiss: @escaping () -> Void,
        onChanged: @escaping () -> Void,
        onDeleted: ((MealEntrySnapshot) -> Void)? = nil
    ) {
        self.meal = meal
        self.repository = repository
        self.photoStore = photoStore
        self.onDismiss = onDismiss
        self.onChanged = onChanged
        self.onDeleted = onDeleted
        self._portion = State(initialValue: meal.portionMultiplier)
        self._tags = State(initialValue: meal.tags)
        self._notes = State(initialValue: meal.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Tokens.Palette.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: Tokens.Space.lg) {
                        if let photo = mealPhoto {
                            photoHeader(photo)
                        }
                        summaryCard
                        portionCard
                        tagsCard
                        notesCard
                        itemsCard
                        if let errorMessage {
                            Text(errorMessage)
                                .font(Tokens.Font.footnote)
                                .foregroundStyle(Tokens.Palette.warning)
                        }
                        PrimaryButton(title: "Zapisz zmiany", systemImage: "checkmark") {
                            save()
                        }
                        Button {
                            duplicate()
                        } label: {
                            HStack(spacing: Tokens.Space.sm) {
                                Image(systemName: "doc.on.doc")
                                Text("Duplikuj na dziś")
                            }
                            .font(Tokens.Font.bodyEmphasized)
                            .foregroundStyle(Tokens.Palette.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Tokens.Space.md)
                            .background(
                                RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                                    .fill(Tokens.Palette.primarySoft)
                            )
                        }
                        .buttonStyle(.plain)
                        Button(role: .destructive) {
                            isConfirmingDelete = true
                        } label: {
                            HStack(spacing: Tokens.Space.sm) {
                                Image(systemName: "trash")
                                Text("Usuń posiłek")
                            }
                            .font(Tokens.Font.bodyEmphasized)
                            .foregroundStyle(Tokens.Palette.warning)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Tokens.Space.md)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.vertical, Tokens.Space.lg)
                }
            }
            .navigationTitle(Text(mealTypeLabel))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Zamknij", action: onDismiss)
                }
            }
            .confirmationDialog(
                "Na pewno usunąć?",
                isPresented: $isConfirmingDelete,
                titleVisibility: .visible
            ) {
                Button("Usuń posiłek", role: .destructive) { delete() }
                Button("Anuluj", role: .cancel) {}
            } message: {
                Text("Wpis zostanie skasowany i wyleci z dziennika.")
            }
            .fullScreenCover(item: $zoomedPhoto) { zoomed in
                MealPhotoZoomView(image: zoomed.image) {
                    zoomedPhoto = nil
                }
            }
        }
    }

    // MARK: - Sections

    private var mealPhoto: UIImage? {
        guard let filename = meal.photoFilename, let photoStore else { return nil }
        return photoStore.image(forFilename: filename)
    }

    private func photoHeader(_ image: UIImage) -> some View {
        Button {
            zoomedPhoto = ZoomedPhoto(image: image)
            Haptics.light()
        } label: {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(.black.opacity(0.4), in: Circle())
                        .padding(8)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Powiększ zdjęcie"))
    }

    private var summaryCard: some View {
        Card(elevation: Tokens.Shadow.float) {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                Text(Self.timeFormatter.string(from: meal.consumedAt))
                    .font(Tokens.Font.subheadline)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                Text("\(Int(adjustedCalories)) kcal")
                    .font(Tokens.Font.counter)
                    .foregroundStyle(Tokens.Palette.primary)
                HStack(spacing: Tokens.Space.lg) {
                    macroPill(label: "Białko", grams: adjustedProtein)
                    macroPill(label: "Węgle", grams: adjustedCarbs)
                    macroPill(label: "Tłuszcz", grams: adjustedFat)
                }
            }
        }
    }

    private var portionCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                HStack {
                    Text("Porcja")
                        .font(Tokens.Font.headline)
                        .foregroundStyle(Tokens.Palette.ink)
                    Spacer()
                    Text(String(format: "×%.2f", portion))
                        .font(Tokens.Font.bodyEmphasized)
                        .foregroundStyle(Tokens.Palette.primary)
                }
                Slider(value: $portion, in: 0.25...3.0, step: 0.05)
                    .tint(Tokens.Palette.primary)
                Text("Skala dotyczy wszystkich pozycji w tym wpisie.")
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Palette.inkSubtle)
            }
        }
    }

    private var tagsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                Text("Tagi")
                    .font(Tokens.Font.headline)
                    .foregroundStyle(Tokens.Palette.ink)
                if tags.isEmpty {
                    Text("Dodaj tagi typu: restauracja, treningowy, domowe.")
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Palette.inkSubtle)
                } else {
                    FlowLayout {
                        ForEach(tags, id: \.self) { tag in
                            tagChip(tag)
                        }
                    }
                }
                HStack(spacing: Tokens.Space.sm) {
                    TextField("nowy tag", text: $newTag)
                        .textInputAutocapitalization(.never)
                        .submitLabel(.done)
                        .onSubmit { commitNewTag() }
                        .padding(Tokens.Space.sm)
                        .background(
                            RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                                .fill(Tokens.Palette.surfaceMuted)
                        )
                    Button {
                        commitNewTag()
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Tokens.Palette.primary))
                    }
                    .disabled(newTag.trimmingCharacters(in: .whitespaces).isEmpty)
                    .opacity(newTag.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
                }
            }
        }
    }

    private func tagChip(_ tag: String) -> some View {
        HStack(spacing: 4) {
            Text(tag)
                .font(Tokens.Font.caption)
                .foregroundStyle(Tokens.Palette.primary)
            Button {
                tags.removeAll { $0 == tag }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Tokens.Palette.primary.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Tokens.Space.sm)
        .padding(.vertical, 4)
        .background(Capsule().fill(Tokens.Palette.primarySoft))
    }

    private func commitNewTag() {
        let cleaned = newTag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cleaned.isEmpty, !tags.contains(cleaned) else { return }
        tags.append(cleaned)
        newTag = ""
    }

    private var notesCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                Text("Notatka")
                    .font(Tokens.Font.headline)
                    .foregroundStyle(Tokens.Palette.ink)
                TextEditor(text: $notes)
                    .font(Tokens.Font.body)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 88)
                    .padding(Tokens.Space.sm)
                    .background(
                        RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                            .fill(Tokens.Palette.surfaceMuted)
                    )
                Text("Co poszło dobrze, co warto zmienić? Zostanie w historii posiłku.")
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Palette.inkSubtle)
            }
        }
    }

    private var itemsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                Text("Pozycje")
                    .font(Tokens.Font.headline)
                    .foregroundStyle(Tokens.Palette.ink)
                ForEach(meal.items) { item in
                    itemRow(item)
                }
            }
        }
    }

    private func itemRow(_ item: FoodItem) -> some View {
        HStack(spacing: Tokens.Space.md) {
            Circle()
                .fill(Tokens.Palette.primarySoft)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(Tokens.Font.body)
                    .foregroundStyle(Tokens.Palette.ink)
                Text("\(Int(item.quantityGrams)) g")
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)
            }
            Spacer()
            Text("\(Int(item.caloriesKcal * portion)) kcal")
                .font(Tokens.Font.bodyEmphasized)
                .foregroundStyle(Tokens.Palette.ink)
        }
    }

    private func macroPill(label: LocalizedStringKey, grams: Double) -> some View {
        VStack(spacing: 2) {
            Text("\(Int(grams)) g")
                .font(Tokens.Font.bodyEmphasized)
                .foregroundStyle(Tokens.Palette.primary)
            Text(label)
                .font(Tokens.Font.caption)
                .foregroundStyle(Tokens.Palette.inkMuted)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Actions

    private func save() {
        do {
            try repository.updatePortion(meal, multiplier: portion)
            try repository.updateTags(meal, tags: tags)
            try repository.updateNotes(meal, notes: notes)
            onChanged()
            onDismiss()
        } catch {
            errorMessage = String(localized: "Nie udało się zapisać. Spróbuj ponownie.")
        }
    }

    private func duplicate() {
        do {
            try repository.duplicate(meal)
            Haptics.success()
            onChanged()
            onDismiss()
        } catch {
            errorMessage = String(localized: "Nie udało się zduplikować. Spróbuj ponownie.")
        }
    }

    private func delete() {
        let snapshot = MealEntrySnapshot.capture(from: meal)
        do {
            let filenameToCleanup = meal.photoFilename
            try repository.delete(meal)
            Haptics.warning()
            // Fire the photo deletion after the 5s undo window closes
            // so a Cofnij tap can still restore with the original JPEG.
            if let filename = filenameToCleanup, let photoStore {
                Task {
                    try? await Task.sleep(nanoseconds: 6_000_000_000)
                    // Undo banner may have restored a meal that still
                    // points at this filename; skip the delete if so.
                    if repository.photoIsOrphaned(filename: filename) {
                        photoStore.delete(filename: filename)
                    }
                }
            }
            onDeleted?(snapshot)
            onChanged()
            onDismiss()
        } catch {
            errorMessage = String(localized: "Nie udało się usunąć. Spróbuj ponownie.")
        }
    }

    // MARK: - Derived

    private var adjustedCalories: Double {
        meal.items.reduce(0) { $0 + $1.caloriesKcal } * portion
    }
    private var adjustedProtein: Double {
        meal.items.reduce(0) { $0 + $1.proteinGrams } * portion
    }
    private var adjustedCarbs: Double {
        meal.items.reduce(0) { $0 + $1.carbsGrams } * portion
    }
    private var adjustedFat: Double {
        meal.items.reduce(0) { $0 + $1.fatGrams } * portion
    }

    private var mealTypeLabel: LocalizedStringKey {
        switch meal.mealType {
        case .breakfast: return "Śniadanie"
        case .lunch: return "Obiad"
        case .dinner: return "Kolacja"
        case .snack: return "Przekąska"
        }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, HH:mm"
        formatter.locale = Locale(identifier: "pl_PL")
        return formatter
    }()
}
// swiftlint:enable type_body_length
