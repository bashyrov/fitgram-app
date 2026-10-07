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
    @State private var isTimePickerExpanded = false

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
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let photo = mealPhoto {
                        photoHeader(photo)
                            .padding(.top, 6)
                    }
                    titleBlock
                        .padding(.top, 16)
                    MonoMacroRow(protein: adjustedProtein, carbs: adjustedCarbs, fat: adjustedFat)
                        .padding(.top, 14)
                    timeCard
                        .padding(.top, 14)
                    favoriteButton
                        .padding(.top, 10)
                    ratingCard
                        .padding(.top, 10)
                    portionCard
                        .padding(.top, 10)
                    tagsCard
                        .padding(.top, 10)
                    notesCard
                        .padding(.top, 10)
                    MonoSectionHeader(title: L("Pozycje"))
                        .padding(.horizontal, 6)
                        .padding(.top, 8)
                        .padding(.bottom, 12)
                    itemsCard
                    if let errorMessage {
                        Text(errorMessage)
                            .font(Tokens.Font.manrope(13, weight: 700))
                            .foregroundStyle(Tokens.Mono.danger)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 6)
                            .padding(.top, 12)
                    }
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.bottom, Tokens.Space.lg)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Tokens.Palette.background.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                MonoBottomBar {
                    MonoButton(title: L("Zapisz zmiany"), kind: .dark, icon: "checkmark") {
                        save()
                    }
                    HStack(spacing: 8) {
                        MonoButton(title: L("Duplicate to today"), kind: .outline, icon: "doc.on.doc") {
                            duplicate()
                        }
                        MonoButton(title: L("Usuń posiłek"), kind: .danger, icon: "trash") {
                            isConfirmingDelete = true
                        }
                    }
                }
            }
            .monoNavigationTitle(mealTypeLabel)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    MonoNavText(title: L("Close"), action: onDismiss)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    MonoNavPill(title: L("Zapisz zmiany")) {
                        save()
                    }
                }
            }
            .confirmationDialog(
                "Na pewno usunąć?",
                isPresented: $isConfirmingDelete,
                titleVisibility: .visible
            ) {
                Button("Usuń posiłek", role: .destructive) { delete() }
                Button("Cancel", role: .cancel) {}
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

    // Mockup: 200 pt photo (radius 22) with a dark "Powiększ zdjęcie" pill bottom-right.
    private func photoHeader(_ image: UIImage) -> some View {
        Button {
            zoomedPhoto = ZoomedPhoto(image: image)
            Haptics.light()
        } label: {
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .overlay {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(alignment: .bottomTrailing) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 11, weight: .bold))
                        Text(L("Powiększ zdjęcie"))
                            .font(Tokens.Font.manrope(12, weight: 800))
                    }
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 12)
                    .frame(height: 34)
                    .background(Capsule().fill(Color(red: 10 / 255, green: 11 / 255, blue: 12 / 255).opacity(0.7)))
                    .padding(10)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(L("Powiększ zdjęcie")))
    }

    // Mockup: "OBIAD · 13:30" label + meal name (display 24) with the kcal number on the right.
    private var titleBlock: some View {
        HStack(alignment: .bottom, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                MonoLabel(text: mealTypeLabel + " · " + Self.clockFormatter.string(from: consumedAt))
                Text(mealName)
                    .font(Tokens.Font.monoDisplay(24))
                    .foregroundStyle(Tokens.Palette.ink)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(verbatim: "\(Int(adjustedCalories.rounded()))")
                    .font(Tokens.Font.monoNumber(32))
                    .foregroundStyle(Tokens.Palette.ink)
                    .contentTransition(.numericText())
                Text(verbatim: " kcal")
                    .font(Tokens.Font.manrope(13, weight: 700))
                    .foregroundStyle(Tokens.Mono.muted)
            }
            .lineLimit(1)
            .fixedSize()
        }
        .padding(.horizontal, 6)
    }

    // Mockup: rows card "Pora posiłku" with the time and a chevron; expands an inline picker.
    private var timeCard: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(Tokens.Motion.gentle) {
                    isTimePickerExpanded.toggle()
                }
                Haptics.selection()
            } label: {
                MonoRow(icon: "clock", title: mealTimeTitle, sub: consumedAtDescription) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Tokens.Mono.muted)
                        .rotationEffect(.degrees(isTimePickerExpanded ? 180 : 0))
                }
            }
            .buttonStyle(.plain)
            if isTimePickerExpanded {
                MonoRowDivider(inset: 16)
                DatePicker(
                    "",
                    selection: $consumedAt,
                    in: ...Date(),
                    displayedComponents: [.date, .hourAndMinute]
                )
                .labelsHidden()
                .datePickerStyle(.graphical)
                .tint(Tokens.Mono.strong)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
        }
        .monoRowsCard()
    }

    // Mockup: "OCENA" label + "Wyczyść", five 26 pt stars (fat colour when filled).
    private var ratingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                MonoLabel(text: L("Ocena"))
                Spacer()
                if rating != nil {
                    Button {
                        rating = nil
                        Haptics.light()
                    } label: {
                        Text(L("Clear"))
                            .font(Tokens.Font.manrope(13, weight: 700))
                            .foregroundStyle(Tokens.Mono.muted)
                            .frame(height: 32)
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack(spacing: 10) {
                ForEach(1...5, id: \.self) { star in
                    Button {
                        rating = star
                        Haptics.light()
                    } label: {
                        let filled = star <= (rating ?? 0)
                        Image(systemName: filled ? "star.fill" : "star")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(filled ? Tokens.Mono.fat : Tokens.Mono.line2)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(String.localizedStringWithFormat(L("Oceń %lld gwiazdek"), star)))
                }
                Spacer(minLength: 0)
            }
        }
        .monoCard(padding: 16)
    }

    // Mockup: "PORCJA" label + grams, slider with min/max captions, muted hint.
    private var portionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                MonoLabel(text: L("Porcja"))
                Spacer()
                Text(String.localizedStringWithFormat(L("%lld g"), Int(totalAdjustedGrams.rounded())))
                    .font(Tokens.Font.monoNumber(18))
                    .foregroundStyle(Tokens.Palette.ink)
                    .lineLimit(1)
                    .contentTransition(.numericText())
            }
            VStack(spacing: 6) {
                Slider(value: $portion, in: 0.25...3.0, step: 0.05)
                    .tint(Tokens.Mono.strong)
                HStack {
                    Text(String.localizedStringWithFormat(L("%lld g"), Int((baseGrams * 0.25).rounded())))
                    Spacer()
                    Text(String.localizedStringWithFormat(L("%lld g"), Int((baseGrams * 3).rounded())))
                }
                .font(Tokens.Font.manrope(11, weight: 700))
                .foregroundStyle(Tokens.Mono.muted)
            }
            Text(L("Skala dotyczy wszystkich pozycji w tym wpisie."))
                .font(Tokens.Font.manrope(12, weight: 600))
                .foregroundStyle(Tokens.Mono.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .monoCard(padding: 16)
    }

    private var baseGrams: Double {
        meal.items.reduce(0) { $0 + $1.quantityGrams }
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
            let payload = favoritePayload
        {
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

    // Mockup: "TAGI" label, hint, track chips with ×, bordered input + dark square add button.
    private var tagsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            MonoLabel(text: L("Tags"))
            Text(L("Dodaj tagi typu: restauracja, treningowy, domowe."))
                .font(Tokens.Font.manrope(12, weight: 600))
                .foregroundStyle(Tokens.Mono.muted)
                .fixedSize(horizontal: false, vertical: true)
            if !tags.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(tags, id: \.self) { tag in
                        tagChip(tag)
                    }
                }
            }
            HStack(spacing: 8) {
                TextField(L("nowy tag"), text: $newTag)
                    .font(Tokens.Font.manrope(14, weight: 600))
                    .foregroundStyle(Tokens.Palette.ink)
                    .textInputAutocapitalization(.never)
                    .submitLabel(.done)
                    .onSubmit { commitNewTag() }
                    .padding(.horizontal, 14)
                    .frame(height: 44)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Tokens.Mono.line2, lineWidth: 1)
                    )
                Button {
                    commitNewTag()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(Tokens.Mono.onHero)
                        .frame(width: 44, height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Tokens.Mono.hero)
                        )
                }
                .buttonStyle(.plain)
                .disabled(newTag.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(newTag.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
                .accessibilityLabel(Text(L("Add tag")))
            }
            if !tagSuggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(tagSuggestions, id: \.self) { suggestion in
                            Button {
                                add(tag: suggestion)
                            } label: {
                                Text(suggestion)
                                    .font(Tokens.Font.manrope(13, weight: 700))
                                    .foregroundStyle(Tokens.Palette.ink)
                                    .padding(.horizontal, 12)
                                    .frame(height: 32)
                                    .overlay(Capsule().stroke(Tokens.Mono.line2, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .monoCard(padding: 16)
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
                .font(Tokens.Font.manrope(13, weight: 700))
                .foregroundStyle(Tokens.Palette.ink)
            Button {
                tags.removeAll { $0 == tag }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(Tokens.Mono.muted)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 12)
        .padding(.trailing, 6)
        .frame(height: 32)
        .background(Capsule().fill(Tokens.Mono.track))
    }

    private func commitNewTag() {
        let cleaned = newTag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cleaned.isEmpty, !tags.contains(cleaned) else { return }
        tags.append(cleaned)
        newTag = ""
    }

    // Mockup: "NOTATKA" label + bordered 70 pt editor with the hint as placeholder.
    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            MonoLabel(text: L("Note"))
            ZStack(alignment: .topLeading) {
                if notes.isEmpty {
                    Text(L("Co poszło dobrze, co warto zmienić? Zostanie w historii posiłku."))
                        .font(Tokens.Font.manrope(14, weight: 600))
                        .foregroundStyle(Tokens.Mono.muted)
                        .lineSpacing(3)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $notes)
                    .font(Tokens.Font.manrope(14, weight: 600))
                    .foregroundStyle(Tokens.Palette.ink)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
            }
            .frame(minHeight: 70)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Tokens.Mono.line2, lineWidth: 1)
            )
        }
        .monoCard(padding: 16)
    }

    // Mockup: rows card (divider inset 16), name + "180 g · 4 g B · …" + italic kcal.
    private var itemsCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(meal.items.enumerated()), id: \.element.id) { index, item in
                if index > 0 {
                    MonoRowDivider(inset: 16)
                }
                itemRow(item)
            }
        }
        .monoRowsCard()
    }

    private func itemRow(_ item: FoodItem) -> some View {
        MonoRow(title: item.name, sub: itemSubtitle(item)) {
            Text(verbatim: "\(Int((item.caloriesKcal * portion).rounded()))")
                .font(Tokens.Font.monoNumber(18))
                .foregroundStyle(Tokens.Palette.ink)
                .lineLimit(1)
                .fixedSize()
        }
        .accessibilityElement(children: .combine)
    }

    private func itemSubtitle(_ item: FoodItem) -> String {
        let letters = TL(pl: "B|W|T", en: "P|C|F", uk: "Б|В|Ж", ru: "Б|У|Ж", es: "P|C|G")
            .split(separator: "|")
            .map(String.init)
        let proteinLetter = letters.first ?? "P"
        let carbsLetter = letters.count > 1 ? letters[1] : "C"
        let fatLetter = letters.count > 2 ? letters[2] : "F"
        let grams = Int((item.quantityGrams * portion).rounded())
        let protein = Int((item.proteinGrams * portion).rounded())
        let carbs = Int((item.carbsGrams * portion).rounded())
        let fat = Int((item.fatGrams * portion).rounded())
        return "\(grams) g · \(protein) g \(proteinLetter) · \(carbs) g \(carbsLetter) · \(fat) g \(fatLetter)"
    }

    private var mealName: String {
        let names = meal.items.map(\.name).filter { !$0.isEmpty }
        if names.isEmpty { return mealTypeLabel }
        return names.count > 1 ? names.joined(separator: " + ") : names[0]
    }

    private var mealTimeTitle: String {
        TL(pl: "Pora posiłku", en: "Meal time", uk: "Час прийому їжі", ru: "Время приёма пищи", es: "Hora de la comida")
    }

    private var consumedAtDescription: String {
        let clock = Self.clockFormatter.string(from: consumedAt)
        if Calendar.current.isDateInToday(consumedAt) {
            return L("Dziś") + ", " + clock
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: LocalizationStore.currentLanguageCode())
        formatter.setLocalizedDateFormatFromTemplate("EEEEdMMM")
        return formatter.string(from: consumedAt) + ", " + clock
    }

    private static var clockFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: LocalizationStore.currentLanguageCode())
        return formatter
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
            errorMessage = L("Nie udało się zapisać. Spróbuj ponownie.")
        }
    }

    private func duplicate() {
        do {
            try repository.duplicate(meal)
            Haptics.success()
            onChanged()
            onDismiss()
        } catch {
            errorMessage = L("Nie udało się zduplikować. Spróbuj ponownie.")
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
            errorMessage = L("Nie udało się usunąć. Spróbuj ponownie.")
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

    private var mealTypeLabel: String {
        switch meal.mealType {
        case .breakfast: return L("Breakfast")
        case .lunch: return L("Lunch")
        case .dinner: return L("Dinner")
        case .snack: return L("Snack")
        }
    }

    private static var timeFormatter: DateFormatter {

        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, HH:mm"
        formatter.locale = Locale(identifier: LocalizationStore.currentLanguageCode())
        return formatter

    }
}
// swiftlint:enable type_body_length
