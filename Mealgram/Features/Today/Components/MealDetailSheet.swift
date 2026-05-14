import SwiftUI

// swiftlint:disable type_body_length file_length

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
    var favoritesService: (any FavoritesServing)?
    var entitlementsStore: EntitlementsStore?
    var paywallCoordinator: PaywallCoordinator?
    var userRemoteID: String?

    @State private var portion: Double
    @State private var consumedAt: Date
    @State private var rating: Int?
    @State private var isConfirmingDelete = false
    @State private var errorMessage: String?
    @State private var tags: [String]
    @State private var newTag: String = ""
    @State private var notes: String
    @State private var zoomedPhoto: ZoomedPhoto?
    @State private var knownTags: [String] = []

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
        onDeleted: ((MealEntrySnapshot) -> Void)? = nil,
        favoritesService: (any FavoritesServing)? = nil,
        entitlementsStore: EntitlementsStore? = nil,
        paywallCoordinator: PaywallCoordinator? = nil,
        userRemoteID: String? = nil
    ) {
        self.meal = meal
        self.repository = repository
        self.photoStore = photoStore
        self.onDismiss = onDismiss
        self.onChanged = onChanged
        self.onDeleted = onDeleted
        self.favoritesService = favoritesService
        self.entitlementsStore = entitlementsStore
        self.paywallCoordinator = paywallCoordinator
        self.userRemoteID = userRemoteID
        self._portion = State(initialValue: meal.portionMultiplier)
        self._consumedAt = State(initialValue: meal.consumedAt)
        self._rating = State(initialValue: meal.rating)
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
                        favoriteButton
                        portionCard
                        ratingCard
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

    private var ratingCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                HStack {
                    Text("Ocena")
                        .font(Tokens.Font.headline)
                        .foregroundStyle(Tokens.Palette.ink)
                    Spacer()
                    if rating != nil {
                        Button("Wyczyść") {
                            rating = nil
                            Haptics.light()
                        }
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                    }
                }
                HStack(spacing: Tokens.Space.xs) {
                    ForEach(1...5, id: \.self) { star in
                        Button {
                            rating = star
                            Haptics.light()
                        } label: {
                            let filled = star <= (rating ?? 0)
                            Image(systemName: filled ? "star.fill" : "star")
                                .font(.title3)
                                .foregroundStyle(filled ? Tokens.Palette.warning : Tokens.Palette.inkSubtle)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text("Oceń \(star) gwiazdek"))
                    }
                    Spacer()
                }
            }
        }
    }

    private var summaryCard: some View {
        Card(elevation: Tokens.Shadow.float) {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                DatePicker(
                    "",
                    selection: $consumedAt,
                    in: ...Date(),
                    displayedComponents: [.date, .hourAndMinute]
                )
                .labelsHidden()
                .datePickerStyle(.compact)
                .tint(Tokens.Palette.primary)
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
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(Int(totalAdjustedGrams)) g")
                            .font(Tokens.Font.title3)
                            .foregroundStyle(Tokens.Palette.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Text(String(format: "×%.2f", portion))
                            .font(Tokens.Font.caption)
                            .foregroundStyle(Tokens.Palette.inkMuted)
                    }
                }
                Slider(value: $portion, in: 0.25...3.0, step: 0.05)
                    .tint(Tokens.Palette.primary)
                Text("Skala dotyczy wszystkich pozycji w tym wpisie.")
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Palette.inkSubtle)
            }
        }
    }

    private var totalAdjustedGrams: Double {
        meal.items.reduce(0) { $0 + $1.quantityGrams } * portion
    }

    /// Save the whole meal as a single favourite template — sum macros
    /// across items, take the first item's name (or join all) as the
    /// favourite title. Premium-gated via FavoriteToggleButton itself.
    @ViewBuilder
    private var favoriteButton: some View {
        if let favoritesService,
            let entitlementsStore,
            let paywallCoordinator,
            let userRemoteID,
            let payload = favoritePayload {
            FavoriteToggleButton(
                payload: payload,
                userRemoteID: userRemoteID,
                favoritesService: favoritesService,
                entitlementsStore: entitlementsStore,
                paywallCoordinator: paywallCoordinator
            )
        }
    }

    private var favoritePayload: FavoriteToggleButton.Payload? {
        guard let first = meal.items.first else { return nil }
        let name: String =
            meal.items.count > 1
                ? meal.items.map(\.name).joined(separator: " + ")
                : first.name
        let totalGrams = meal.items.reduce(0) { $0 + $1.quantityGrams } * portion
        return FavoriteToggleButton.Payload(
            name: name,
            quantityGrams: totalGrams,
            caloriesKcal: meal.totalCaloriesKcal,
            proteinGrams: meal.totalProteinGrams,
            carbsGrams: meal.totalCarbsGrams,
            fatGrams: meal.totalFatGrams,
            fiberGrams: nil,
            source: meal.source,
            catalogFoodID: meal.items.count == 1 ? first.catalogFoodID : nil
        )
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
                if !tagSuggestions.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Tokens.Space.sm) {
                            ForEach(tagSuggestions, id: \.self) { suggestion in
                                Button {
                                    add(tag: suggestion)
                                } label: {
                                    Text(suggestion)
                                        .font(Tokens.Font.caption)
                                        .foregroundStyle(Tokens.Palette.inkMuted)
                                        .padding(.horizontal, Tokens.Space.sm)
                                        .padding(.vertical, 4)
                                        .background(
                                            Capsule().stroke(Tokens.Palette.separator, lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
        .task {
            knownTags = (try? repository.knownTags()) ?? []
        }
    }

    /// Up to 6 known tags that match the current input prefix and aren't
    /// already on the meal. Empty input shows the top tags by frequency.
    private var tagSuggestions: [String] {
        let trimmed = newTag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let candidates = knownTags.filter { !tags.contains($0) }
        let matching =
            trimmed.isEmpty
            ? candidates
            : candidates.filter { $0.hasPrefix(trimmed) }
        return Array(matching.prefix(6))
    }

    private func add(tag: String) {
        guard !tags.contains(tag) else { return }
        tags.append(tag)
        newTag = ""
        Haptics.light()
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
            if rating != meal.rating {
                try repository.updateRating(meal, rating: rating)
            }
            if !Calendar.current.isDate(consumedAt, equalTo: meal.consumedAt, toGranularity: .minute) {
                try repository.updateConsumedAt(meal, to: consumedAt)
            }
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
            // Fire the photo deletion after the 8s undo window closes
            // so a Cofnij tap can still restore with the original JPEG.
            if let filename = filenameToCleanup, let photoStore {
                Task {
                    try? await Task.sleep(nanoseconds: 9_000_000_000)
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
