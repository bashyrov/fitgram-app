import SwiftUI

// swiftlint:disable file_length
/// Routes the voice-capture stages: permission gate → idle → listening
/// → finished/confirm → save. AI parsing of the transcript (Claude via
/// Worker) slots in here once the Worker has credentials.
struct VoiceRootView: View {
    @State private var state: VoiceFlowState
    let parser: VoiceMealParser
    let mealAnalyzer: MealTextAnalysisService?
    let entitlementsStore: EntitlementsStore?
    let paywallCoordinator: PaywallCoordinator?
    let usageMeter: UsageMeter?
    let onDismiss: () -> Void
    @State private var saveError: String?

    init(
        session: VoiceCaptureSession = VoiceCaptureSession(),
        mealSaver: any MealSaving,
        parser: VoiceMealParser = VoiceMealParser(),
        mealAnalyzer: MealTextAnalysisService? = nil,
        entitlementsStore: EntitlementsStore? = nil,
        paywallCoordinator: PaywallCoordinator? = nil,
        usageMeter: UsageMeter? = nil,
        onDismiss: @escaping () -> Void
    ) {
        self.parser = parser
        self.mealAnalyzer = mealAnalyzer
        self.entitlementsStore = entitlementsStore
        self.paywallCoordinator = paywallCoordinator
        self.usageMeter = usageMeter
        self._state = State(
            initialValue: VoiceFlowState(session: session, mealSaver: mealSaver, parser: parser)
        )
        self.onDismiss = onDismiss
    }

    var body: some View {
        ZStack {
            Tokens.Palette.background.ignoresSafeArea()
            switch state.stage {
            case .checkingPermission:
                ProgressView()
                    .tint(Tokens.Palette.primary)
            case .needsPermission(let status):
                VoicePermissionGate(
                    status: status,
                    onRetry: { Task { await state.start() } },
                    onDismiss: onDismiss
                )
            case .idle, .listening:
                VStack(spacing: 0) {
                    AddFlowNavBar(title: L("Meal by voice"), onLeft: onDismiss)
                    VoiceCaptureView(
                        isListening: isListening,
                        meter: state.levelMeter,
                        transcript: state.partialTranscript,
                        onToggle: toggleCapture
                    )
                }
            case .finished(let transcript):
                ConfirmationView(
                    transcript: transcript,
                    parser: parser,
                    mealAnalyzer: mealAnalyzer,
                    entitlementsStore: entitlementsStore,
                    paywallCoordinator: paywallCoordinator,
                    usageMeter: usageMeter,
                    onSave: { items in commit(items: items) },
                    onRetake: { state.reset() },
                    onDismiss: onDismiss
                )
            case .error(let message):
                VStack(spacing: 0) {
                    AddFlowNavBar(title: L("Meal by voice"), onLeft: onDismiss)
                    VoiceMessageBlock(
                        icon: "exclamationmark.triangle",
                        title: L("Something went wrong"),
                        message: L(message)
                    )
                    .padding(.top, 80)
                    Spacer(minLength: 0)
                    MonoBottomBar {
                        MonoButton(title: L("Try again"), kind: .dark, icon: "arrow.clockwise") {
                            Task { await state.start() }
                        }
                        MonoButton(title: L("Close"), kind: .outline, action: onDismiss)
                    }
                }
            }
        }
        .animation(Tokens.Motion.gentle, value: stageKey)
        .alert(
            "Nie udało się zapisać posiłku",
            isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { saveError = nil }
        } message: {
            Text(saveError ?? "Spróbuj ponownie.")
        }
        .task { await state.start() }
        .onDisappear { state.reset() }
    }

    // MARK: - Subviews

    private var isListening: Bool {
        if case .listening = state.stage { return true }
        return false
    }

    private var stageKey: String {
        switch state.stage {
        case .checkingPermission: return "checking"
        case .needsPermission: return "permission"
        case .idle: return "idle"
        case .listening: return "listening"
        case .finished: return "finished"
        case .error: return "error"
        }
    }

    private func toggleCapture() {
        switch state.stage {
        case .idle:
            state.beginListening()
        case .listening:
            state.stopListening()
        default:
            break
        }
    }

    private func commit(items: [FoodItem]) {
        do {
            try state.commit(items: items)
            Haptics.success()
            onDismiss()
        } catch {
            Haptics.warning()
            saveError = L("Couldn't save. Try again.")
        }
    }
}

private struct VoicePermissionGate: View {
    let status: VoicePermission.Status
    let onRetry: () -> Void
    let onDismiss: () -> Void

    /// Mockup `Permissions` microphone card: dark 56 pt icon box, display title, muted copy and
    /// the primary action next to an outline "Zamknij".
    var body: some View {
        VStack(spacing: 0) {
            AddFlowNavBar(title: L("Meal by voice"), onLeft: onDismiss)
            VStack(spacing: 12) {
                VStack(spacing: 10) {
                    MonoIconBox(systemName: "mic.fill", style: .dark, size: 56)
                    Text(L("We need the microphone"))
                        .font(Tokens.Font.monoDisplay(20))
                        .textCase(.uppercase)
                        .foregroundStyle(Tokens.Palette.ink)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(
                        status == .denied
                            ? L("Enable microphone + speech recognition in Settings to dictate meals.")
                            : L("Allow microphone + speech recognition to dictate meals.")
                    )
                    .font(Tokens.Font.manrope(13, weight: 600))
                    .foregroundStyle(Tokens.Mono.muted)
                    .lineSpacing(2)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                HStack(spacing: 8) {
                    MonoButton(
                        title: status == .denied ? L("Open Settings") : L("Allow"),
                        kind: .dark,
                        height: 46
                    ) {
                        if status == .denied {
                            openSettings()
                        } else {
                            onRetry()
                        }
                    }
                    MonoButton(title: L("Close"), kind: .outline, height: 46, action: onDismiss)
                }
            }
            .monoCard(padding: 16)
            .padding(.horizontal, Tokens.Space.screenPadding)
            .padding(.top, 10)
            Spacer(minLength: 0)
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

/// Centred empty-state block from mockup `VoiceNotHeard`: 72 pt track icon box, 24 pt display
/// title and a muted 14 pt explanation.
private struct VoiceMessageBlock: View {
    let icon: String
    let title: String
    let message: String
    var inset: CGFloat = 28

    var body: some View {
        VStack(spacing: 14) {
            MonoIconBox(systemName: icon, style: .track, size: 72)
            Text(title)
                .font(Tokens.Font.monoDisplay(24))
                .textCase(.uppercase)
                .foregroundStyle(Tokens.Palette.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text(message)
                .font(Tokens.Font.manrope(14, weight: 600))
                .foregroundStyle(Tokens.Mono.muted)
                .lineSpacing(3)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, inset)
    }
}

// swiftlint:disable:next type_body_length
private struct ConfirmationView: View {
    let transcript: String
    let parser: VoiceMealParser
    let mealAnalyzer: MealTextAnalysisService?
    let entitlementsStore: EntitlementsStore?
    let paywallCoordinator: PaywallCoordinator?
    let usageMeter: UsageMeter?
    let onSave: ([FoodItem]) -> Void
    let onRetake: () -> Void
    let onDismiss: () -> Void

    @State private var edited: String
    @State private var portionMode: PortionAdjustmentMode = .overall
    @State private var overallName: String
    @State private var overallGrams: Double = 100
    @State private var analyzedItems: [FoodItem]
    @State private var isAnalyzingText = false
    @State private var isCompletingNutrition = false
    /// Per-item portion overrides, keyed by stable row identity. The
    /// parser creates fresh `FoodItem.id` values on every parse, so using
    /// those ids makes sliders appear to snap back after each redraw.
    @State private var grams: [String: Double] = [:]
    @State private var lastParsedKeys: Set<String> = []
    @State private var productLookupsInFlight: Set<String> = []
    @State private var didAttemptInitialAI = false
    @FocusState private var isTextInputFocused: Bool

    init(
        transcript: String,
        parser: VoiceMealParser,
        mealAnalyzer: MealTextAnalysisService?,
        entitlementsStore: EntitlementsStore?,
        paywallCoordinator: PaywallCoordinator?,
        usageMeter: UsageMeter?,
        onSave: @escaping ([FoodItem]) -> Void,
        onRetake: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.transcript = transcript
        self.parser = parser
        self.mealAnalyzer = mealAnalyzer
        self.entitlementsStore = entitlementsStore
        self.paywallCoordinator = paywallCoordinator
        self.usageMeter = usageMeter
        self.onSave = onSave
        self.onRetake = onRetake
        self.onDismiss = onDismiss
        self._edited = State(initialValue: transcript)
        let parsed = parser.parseMultiple(transcript)
        self._overallName = State(initialValue: Self.defaultOverallName(for: parsed))
        self._overallGrams = State(initialValue: Self.totalGrams(for: parsed))
        self._analyzedItems = State(initialValue: parsed)
    }

    private var parsedItems: [FoodItem] {
        analyzedItems
    }

    private var hasRecognizedMeal: Bool {
        VoiceMealParser.hasRecognizableFoodText(edited)
            && analyzedItems.contains(where: VoiceMealParser.isUsableParsedItem)
    }

    private var parsedRows: [VoicePortionRow] {
        parsedItems.enumerated().map { index, item in
            VoicePortionRow(key: portionKey(index: index, item: item), item: item)
        }
    }

    /// Returns each parsed item scaled by the user-chosen portion. The
    /// per-100g macros are computed from the parser-reported baseline
    /// so calories + protein + carbs + fat all stay in sync.
    private var adjustedItems: [FoodItem] {
        guard portionMode == .detailed else { return [overallItem] }
        return parsedRows.map { row in
            let base = row.item
            let chosen = grams[row.key] ?? base.quantityGrams
            let factor = base.quantityGrams > 0 ? chosen / base.quantityGrams : 1
            return FoodItem(
                id: base.id,
                name: base.name,
                quantityGrams: chosen,
                caloriesKcal: base.caloriesKcal * factor,
                proteinGrams: base.proteinGrams * factor,
                carbsGrams: base.carbsGrams * factor,
                fatGrams: base.fatGrams * factor,
                confidence: base.confidence
            )
        }
    }

    private var detailedItems: [FoodItem] {
        parsedRows.compactMap { row in
            let base = row.item
            let trimmedName = base.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedName.isEmpty else { return nil }
            let chosen = grams[row.key] ?? base.quantityGrams
            let factor = base.quantityGrams > 0 ? chosen / base.quantityGrams : 1
            return FoodItem(
                id: base.id,
                name: trimmedName,
                quantityGrams: chosen,
                caloriesKcal: base.caloriesKcal * factor,
                proteinGrams: base.proteinGrams * factor,
                carbsGrams: base.carbsGrams * factor,
                fatGrams: base.fatGrams * factor,
                confidence: base.confidence
            )
        }
    }

    private var overallItem: FoodItem {
        let baseItems = detailedItems
        let factor = overallGrams / max(1, baseItems.reduce(0) { $0 + $1.quantityGrams })
        return FoodItem(
            name: overallName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? Self.defaultOverallName(for: parsedItems)
                : overallName,
            quantityGrams: overallGrams,
            caloriesKcal: baseItems.reduce(0) { $0 + $1.caloriesKcal } * factor,
            proteinGrams: baseItems.reduce(0) { $0 + $1.proteinGrams } * factor,
            carbsGrams: baseItems.reduce(0) { $0 + $1.carbsGrams } * factor,
            fatGrams: baseItems.reduce(0) { $0 + $1.fatGrams } * factor,
            confidence: baseItems.compactMap(\.confidence).max() ?? 0.5
        )
    }

    private var adjustedCalories: Double {
        adjustedItems.reduce(0) { $0 + $1.caloriesKcal }
    }

    private var adjustedGrams: Double {
        adjustedItems.reduce(0) { $0 + $1.quantityGrams }
    }

    private var adjustedProtein: Double {
        adjustedItems.reduce(0) { $0 + $1.proteinGrams }
    }

    private var adjustedCarbs: Double {
        adjustedItems.reduce(0) { $0 + $1.carbsGrams }
    }

    private var adjustedFat: Double {
        adjustedItems.reduce(0) { $0 + $1.fatGrams }
    }

    /// Mockups `VoiceReviewGeneral` / `VoiceReviewDetailed` (and `VoiceNotHeard` when nothing
    /// edible was recognised): nav · total hero · "Co usłyszeliśmy" · portion mode · mode content.
    var body: some View {
        VStack(spacing: 0) {
            confirmationHeader
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 10) {
                    if hasRecognizedMeal {
                        voiceSummaryHero
                            .padding(.top, 10)
                        transcriptCard(showsRetake: true)
                        modePicker
                        if portionMode == .overall {
                            overallPortionCard
                        } else {
                            portionsSection
                        }
                    } else {
                        VoiceMessageBlock(
                            icon: "waveform",
                            title: L("Nie usłyszałem dania"),
                            message: notHeardMessage,
                            inset: 16
                        )
                        .padding(.top, 80)
                        .padding(.bottom, 14)
                        transcriptCard(showsRetake: false)
                    }
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.bottom, 20)
            }
        }
        .background(Tokens.Palette.background.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) { footer }
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Gotowe") {
                    isTextInputFocused = false
                }
                .font(Tokens.Font.bodyEmphasized)
            }
        }
        .onChange(of: edited) { _, _ in
            // When the transcript changes, drop overrides that no longer
            // apply (item id disappeared) so the new parsed items show
            // their default portions.
            let newItems = parser.parseMultiple(edited)
            analyzedItems = newItems
            let currentKeys = Set(
                newItems.enumerated().map { index, item in
                    portionKey(index: index, item: item)
                }
            )
            grams = grams.filter { currentKeys.contains($0.key) }
            lastParsedKeys = currentKeys
            if overallName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                overallName = Self.defaultOverallName(for: newItems)
            }
            overallGrams = max(10, Self.totalGrams(for: newItems))
        }
        .task {
            await analyzeInitialTranscriptIfNeeded()
        }
    }

    private func analyzeInitialTranscriptIfNeeded() async {
        guard !didAttemptInitialAI else { return }
        didAttemptInitialAI = true
        guard VoiceMealParser.hasRecognizableFoodText(edited), let mealAnalyzer else { return }

        let cap = entitlementsStore?.current.aiActionsPerWeek
        guard usageMeter?.canUse(.voiceEntry, cap: cap) != false else {
            paywallCoordinator?.present(.voiceEntryQuota)
            return
        }

        isAnalyzingText = true
        defer { isAnalyzingText = false }
        let suggested = VoiceFlowState.suggestedMealType(
            forHour: Calendar.current.component(.hour, from: Date())
        )
        let analysis = await mealAnalyzer.analyze(
            text: edited,
            mealType: suggested,
            quotaKind: .loggedMeal
        )
        guard analysis.aiSucceeded else { return }

        usageMeter?.record(.voiceEntry, cap: cap)
        analyzedItems = analysis.items.map(Self.foodItem(from:))
        overallName = analysis.overall.name
        overallGrams = max(10, analysis.overall.quantityGrams)
        grams = Dictionary(
            uniqueKeysWithValues: analyzedItems.enumerated().map { index, item in
                (portionKey(index: index, item: item), item.quantityGrams)
            }
        )
        lastParsedKeys = Set(grams.keys)
        Haptics.success()
    }

    private var notHeardMessage: String {
        L("Powiedz nazwę jedzenia, np. „500 g ryżu i 200 g sera”. Dopiero wtedy pokażemy regulację gramów.")
    }

    /// `bottom(...)`: "Dodaj do dziennika" for a recognised meal; "Nagraj ponownie" + "Zamknij"
    /// when nothing was heard (mockup `VoiceNotHeard`).
    @ViewBuilder
    private var footer: some View {
        if hasRecognizedMeal {
            MonoBottomBar {
                MonoButton(
                    title: isCompletingNutrition ? L("Uzupełniam...") : L("Dodaj do dziennika"),
                    kind: .dark,
                    icon: isCompletingNutrition ? "sparkles" : "checkmark"
                ) {
                    Task { await saveAdjustedItems() }
                }
                .disabled(isCompletingNutrition)
            }
        } else {
            MonoBottomBar {
                MonoButton(title: L("Nagraj ponownie"), kind: .dark, icon: "mic.fill", action: onRetake)
                MonoButton(title: L("Zamknij"), kind: .outline, action: onDismiss)
            }
        }
    }

    /// `nav('Sprawdź wpis', 'Zamknij', 'Gotowe', 'pill')` / `nav('Posiłek głosem', 'Zamknij')`.
    private var confirmationHeader: some View {
        AddFlowNavBar(
            title: hasRecognizedMeal ? L("Review entry") : L("Meal by voice"),
            onLeft: onDismiss
        ) {
            if hasRecognizedMeal {
                MonoNavPill(title: L("Gotowe")) {
                    Task { await saveAdjustedItems() }
                }
                .disabled(isCompletingNutrition)
            }
        }
    }

    /// `total_hero(kcal, 'Posiłek głosem · N pozycje · X g', p, c, f, 'mic')`.
    private var voiceSummaryHero: some View {
        AddFlowTotalHero(
            icon: "mic.fill",
            caption: L("Meal by voice") + " · "
                + String.localizedStringWithFormat(
                    L("%lld items · %lld g"),
                    adjustedItems.count,
                    Int(adjustedGrams.rounded())
                ),
            kcal: adjustedCalories,
            protein: adjustedProtein,
            carbs: adjustedCarbs,
            fat: adjustedFat
        )
    }

    /// Card "Co usłyszeliśmy": the (editable) transcript in 16/700 and an outline 36 pt
    /// "Nagraj ponownie" chip. Without a recognised meal it carries the AI refresh instead.
    private func transcriptCard(showsRetake: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            MonoLabel(text: L("What we heard"))
            TextEditor(text: $edited)
                .font(Tokens.Font.manrope(16, weight: 700))
                .foregroundStyle(Tokens.Palette.ink)
                .lineSpacing(4)
                .scrollContentBackground(.hidden)
                .focused($isTextInputFocused)
                .frame(minHeight: 72)
                .padding(.horizontal, -5)
            if showsRetake {
                Button(action: onRetake) {
                    HStack(spacing: 6) {
                        Image(systemName: "mic")
                            .font(.system(size: 12, weight: .bold))
                        Text("Nagraj ponownie")
                            .font(Tokens.Font.manrope(12, weight: 800))
                    }
                    .foregroundStyle(Tokens.Palette.ink)
                    .padding(.horizontal, 12)
                    .frame(height: 36)
                    .overlay(Capsule().stroke(Tokens.Mono.line2, lineWidth: 1))
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            } else {
                HStack {
                    aiRefreshButton
                    Spacer(minLength: 0)
                }
                AIRequestHint.mealRefresh
            }
        }
        .monoCard(padding: 16)
    }

    /// Detailed mode — `ingr_list(..., 'Porcje', 'Produkty usłyszane osobno, z własnymi gramami.')`.
    private var portionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            AddFlowIngredientsSection(
                title: L("Portions"),
                count: parsedRows.count,
                sub: L("Produkty usłyszane osobno, z własnymi gramami.")
            ) {
                ForEach(Array(parsedRows.enumerated()), id: \.element.key) { index, row in
                    portionRow(row, index: index)
                }
            } footer: {
                MonoButton(title: L("Dodaj produkt"), kind: .outline, icon: "plus", height: 44) {
                    addProduct()
                }
                AddFlowAIButton(
                    title: AddFlowCopy.fillWithAI,
                    isLoading: isAnalyzingText,
                    remaining: mealAIRefreshRemaining,
                    showsQuota: false,
                    height: 44,
                    fullWidth: true,
                    isDisabled: isAnalyzingText || edited.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ) {
                    isTextInputFocused = false
                    Task { await refreshFromAI() }
                }
            }
            AIRequestHint.productNutrition
        }
    }

    private func addProduct() {
        let item = FoodItem(
            name: "",
            quantityGrams: 100,
            caloriesKcal: 0,
            proteinGrams: 0,
            carbsGrams: 0,
            fatGrams: 0,
            confidence: 1.0
        )
        analyzedItems.append(item)
        grams[portionKey(index: analyzedItems.count - 1, item: item)] = item.quantityGrams
        Haptics.selection()
    }

    private var modePicker: some View {
        PortionModeSelector(
            selection: $portionMode,
            totalLabel: L("Jedna pozycja z tekstu głosowego."),
            detailLabel: L("Produkty usłyszane osobno, z własnymi gramami."),
            detailCount: max(1, parsedRows.count)
        )
    }

    /// Dark 48 pt "✦ Odśwież AI" (mockup `name_field`) — re-parses the transcript.
    private var aiRefreshButton: some View {
        AddFlowAIButton(
            isLoading: isAnalyzingText,
            remaining: mealAIRefreshRemaining,
            isDisabled: isAnalyzingText || edited.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        ) {
            isTextInputFocused = false
            Task { await refreshFromAI() }
        }
    }

    private var mealAIRefreshRemaining: Int? {
        usageMeter?.remaining(.mealAIRefresh, cap: entitlementsStore?.current.aiActionsPerWeek)
    }

    private var productNutritionRemaining: Int? {
        usageMeter?.remaining(.productNutritionLookup, cap: entitlementsStore?.current.aiActionsPerWeek)
    }

    private func refreshFromAI() async {
        guard VoiceMealParser.hasRecognizableFoodText(edited) else {
            analyzedItems = []
            Haptics.warning()
            return
        }
        let suggested = VoiceFlowState.suggestedMealType(forHour: Calendar.current.component(.hour, from: Date()))
        let cap = entitlementsStore?.current.aiActionsPerWeek
        if mealAnalyzer != nil, usageMeter?.canUse(.mealAIRefresh, cap: cap) == false {
            Haptics.light()
            paywallCoordinator?.present(.mealAIRefreshQuota)
            return
        }
        isAnalyzingText = true
        defer { isAnalyzingText = false }
        let newItems: [FoodItem]
        if let mealAnalyzer {
            let analysis = await mealAnalyzer.analyze(
                text: edited,
                mealType: suggested,
                quotaKind: .mealRefresh
            )
            if analysis.aiSucceeded {
                usageMeter?.record(.mealAIRefresh, cap: cap)
            }
            newItems = analysis.items.map(Self.foodItem(from:))
            overallName = analysis.overall.name
            overallGrams = analysis.overall.quantityGrams
        } else {
            newItems = parser.parseMultiple(edited)
            overallName = Self.defaultOverallName(for: newItems)
            overallGrams = Self.totalGrams(for: newItems)
        }
        analyzedItems = newItems
        grams = Dictionary(
            uniqueKeysWithValues: newItems.enumerated().map { index, item in
                (portionKey(index: index, item: item), item.quantityGrams)
            }
        )
        lastParsedKeys = Set(grams.keys)
        Haptics.success()
    }

    private func saveAdjustedItems() async {
        guard hasRecognizedMeal else {
            Haptics.warning()
            return
        }
        let items = adjustedItems
        guard let mealAnalyzer else {
            onSave(items)
            return
        }
        let suggested = VoiceFlowState.suggestedMealType(forHour: Calendar.current.component(.hour, from: Date()))
        let completionUse = aiCompletionUseCount(for: items)
        guard canConsumeAICompletion(count: completionUse) else { return }
        isCompletingNutrition = true
        defer { isCompletingNutrition = false }
        let completed = await mealAnalyzer.complete(items: items, mealType: suggested)
        recordAICompletion(count: completionUse)
        onSave(completed)
    }

    /// General mode — `name_field` + `portion_card` + the muted "one entry" note.
    private var overallPortionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            AddFlowNameCard(label: L("Nazwa dania")) {
                TextField("Risotto z krewetkami", text: $overallName)
                    .focused($isTextInputFocused)
                    .submitLabel(.done)
                    .onSubmit { isTextInputFocused = false }
            } action: {
                aiRefreshButton
            }
            AIRequestHint.mealRefresh
            AddFlowPortionCard(grams: $overallGrams, range: 10...1500, step: 5)
            MonoHint(text: L("Szczegóły są pod spodem, ale do dziennika trafi jedna pozycja."))
        }
    }

    /// `ingredient(...)` row: red minus, editable name + AI lookup + kcal, grams slider.
    private func portionRow(_ row: VoicePortionRow, index: Int) -> some View {
        let item = row.item
        let binding = Binding<Double>(
            get: { grams[row.key] ?? item.quantityGrams },
            set: { grams[row.key] = $0 }
        )
        let nameBinding = Binding<String>(
            get: {
                guard analyzedItems.indices.contains(index) else { return item.name }
                return analyzedItems[index].name
            },
            set: { newValue in
                guard analyzedItems.indices.contains(index) else { return }
                analyzedItems[index].name = newValue
            }
        )
        let chosen = binding.wrappedValue
        let factor = item.quantityGrams > 0 ? chosen / item.quantityGrams : 1
        var removeAction: (() -> Void)?
        if parsedRows.count > 1 {
            removeAction = {
                analyzedItems.removeAll { $0.id == item.id }
                grams.removeValue(forKey: row.key)
            }
        }
        return AddFlowIngredientRow(
            showsDivider: index > 0,
            kcal: item.caloriesKcal * factor,
            grams: binding,
            range: 10...600,
            step: 5,
            onRemove: removeAction,
            detail: macroSummary(for: item, factor: factor)
        ) {
            TextField("Produkt", text: nameBinding)
                .focused($isTextInputFocused)
                .submitLabel(.done)
                .onSubmit { isTextInputFocused = false }
        } accessory: {
            productAIButton(for: row)
        }
    }

    private func productAIButton(for row: VoicePortionRow) -> some View {
        AIProductLookupButton(
            isLoading: productLookupsInFlight.contains(row.key),
            remaining: productNutritionRemaining,
            isDisabled: productLookupsInFlight.contains(row.key)
                || mealAnalyzer == nil
                || row.item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            accessibilityLabel: L("Uzupełnij produkt AI")
        ) {
            isTextInputFocused = false
            Task { await refreshProductNutrition(row) }
        }
    }

    private func refreshProductNutrition(_ row: VoicePortionRow) async {
        guard let mealAnalyzer else { return }
        let currentGrams = grams[row.key] ?? row.item.quantityGrams
        guard currentGrams > 0, !row.item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let cap = entitlementsStore?.current.aiActionsPerWeek
        if usageMeter?.canUse(.productNutritionLookup, cap: cap) == false {
            Haptics.light()
            paywallCoordinator?.present(.productNutritionQuota)
            return
        }
        productLookupsInFlight.insert(row.key)
        defer { productLookupsInFlight.remove(row.key) }
        let draft = FoodItem(
            id: row.item.id,
            name: row.item.name.trimmingCharacters(in: .whitespacesAndNewlines),
            quantityGrams: currentGrams,
            caloriesKcal: 0,
            proteinGrams: 0,
            carbsGrams: 0,
            fatGrams: 0,
            confidence: row.item.confidence
        )
        let suggested = VoiceFlowState.suggestedMealType(forHour: Calendar.current.component(.hour, from: Date()))
        let analysis = await mealAnalyzer.analyze(
            text: "\(Int(currentGrams.rounded())) g \(draft.name)",
            mealType: suggested,
            quotaKind: .productNutrition
        )
        if analysis.items.count > 1,
            let index = parsedRows.firstIndex(where: { $0.key == row.key })
        {
            let replacement = analysis.items.map { FoodItem(detected: $0) }
            analyzedItems.replaceSubrange(index...index, with: replacement)
            grams.removeValue(forKey: row.key)
            for replacementItem in replacement {
                grams[replacementItem.id.uuidString] = replacementItem.quantityGrams
                lastParsedKeys.insert(replacementItem.id.uuidString)
            }
            if analysis.aiSucceeded {
                usageMeter?.record(.productNutritionLookup, cap: cap)
            }
            Haptics.success()
            return
        }
        let completed = analysis.items.first ?? analysis.overall
        if analysis.aiSucceeded {
            usageMeter?.record(.productNutritionLookup, cap: cap)
        }
        if let index = parsedRows.firstIndex(where: { $0.key == row.key }) {
            analyzedItems[index] = FoodItem(detected: completed, id: row.item.id)
            grams[row.key] = completed.quantityGrams
            lastParsedKeys.insert(row.key)
        }
        Haptics.success()
    }

    private func portionKey(index: Int, item: FoodItem) -> String {
        item.id.uuidString
    }

    private func macroSummary(for item: FoodItem, factor: Double) -> String {
        let protein = Int((item.proteinGrams * factor).rounded())
        let carbs = Int((item.carbsGrams * factor).rounded())
        let fat = Int((item.fatGrams * factor).rounded())
        return "P \(protein) · C \(carbs) · F \(fat) g"
    }

    private static func totalGrams(for items: [FoodItem]) -> Double {
        items.reduce(0) { $0 + $1.quantityGrams }
    }

    private static func defaultOverallName(for items: [FoodItem]) -> String {
        guard !items.isEmpty else { return L("Posiłek") }
        if items.count == 1 { return items[0].name }
        return items.map(\.name).joined(separator: " + ")
    }

    private static func foodItem(from item: ScanResult.DetectedItem) -> FoodItem {
        FoodItem(
            name: item.name,
            quantityGrams: item.quantityGrams,
            caloriesKcal: item.caloriesKcal,
            proteinGrams: item.proteinGrams,
            carbsGrams: item.carbsGrams,
            fatGrams: item.fatGrams,
            confidence: item.confidence
        )
    }

    private func aiCompletionUseCount(for items: [FoodItem]) -> Int {
        let missingCount = items.filter(\.isMissingNutrition).count
        guard missingCount > 0 else { return 0 }
        return portionMode == .overall ? 1 : missingCount
    }

    private func canConsumeAICompletion(count: Int) -> Bool {
        guard count > 0 else { return true }
        let kind: UsageMeter.Kind = portionMode == .overall ? .mealAIRefresh : .productNutritionLookup
        let cap = entitlementsStore?.current.aiActionsPerWeek
        guard let cap, let usageMeter else { return true }
        if usageMeter.used(kind) + count <= cap { return true }
        Haptics.light()
        paywallCoordinator?.present(portionMode == .overall ? .mealAIRefreshQuota : .productNutritionQuota)
        return false
    }

    private func recordAICompletion(count: Int) {
        guard count > 0 else { return }
        let kind: UsageMeter.Kind = portionMode == .overall ? .mealAIRefresh : .productNutritionLookup
        let cap = entitlementsStore?.current.aiActionsPerWeek
        for _ in 0..<count {
            usageMeter?.record(kind, cap: cap)
        }
    }

}

private struct VoicePortionRow: Identifiable {
    let key: String
    let item: FoodItem

    var id: String { key }
}
