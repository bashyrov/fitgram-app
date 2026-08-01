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
                VStack {
                    topBar
                    Spacer(minLength: 0)
                    VoiceCaptureView(
                        isListening: isListening,
                        transcript: state.partialTranscript,
                        onToggle: toggleCapture
                    )
                    Spacer(minLength: 0)
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
                VStack(spacing: Tokens.Space.xl) {
                    Spacer()
                    EmptyState(
                        symbol: "exclamationmark.triangle.fill",
                        title: "Something went wrong",
                        message: LocalizedStringKey(message),
                        action: .init(title: "Try again", perform: { Task { await state.start() } })
                    )
                    Spacer()
                    SecondaryButton(title: "Close", systemImage: "xmark", action: onDismiss)
                        .padding(.horizontal, Tokens.Space.screenPadding)
                        .padding(.bottom, Tokens.Space.xl)
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

    private var topBar: some View {
        HStack {
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Tokens.Palette.inkMuted)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Tokens.Palette.surfaceMuted))
            }
            .padding(.leading, Tokens.Space.screenPadding)
            .padding(.top, Tokens.Space.md)
            .accessibilityLabel(Text("Close"))
            Spacer()
        }
    }

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

    var body: some View {
        VStack(spacing: Tokens.Space.xl) {
            Spacer()
            EmptyState(
                symbol: "mic.slash.fill",
                title: "We need the microphone",
                message: status == .denied
                    ? "Enable microphone + speech recognition in Settings to dictate meals."
                    : "Allow microphone + speech recognition to dictate meals.",
                action: status == .denied
                    ? .init(title: "Open Settings", perform: openSettings)
                    : .init(title: "Allow", perform: onRetry)
            )
            Spacer()
            SecondaryButton(title: "Close", systemImage: "xmark", action: onDismiss)
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.bottom, Tokens.Space.xl)
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
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

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Tokens.Palette.background,
                    Tokens.Palette.primarySoft.opacity(0.42),
                    Tokens.Palette.accentSoft.opacity(0.30),
                    Tokens.Palette.background,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                confirmationHeader

                ScrollView(showsIndicators: false) {
                    VStack(spacing: Tokens.Space.lg) {
                        if hasRecognizedMeal {
                            voiceSummaryHero
                            transcriptCard
                            modePicker
                            if portionMode == .overall {
                                overallPortionCard
                            }
                            portionsCard
                        } else {
                            noMealHeardCard
                            transcriptCard
                        }
                    }
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.bottom, Tokens.Space.xl)
                }

                VStack(spacing: Tokens.Space.sm) {
                    PrimaryButton(
                        title: isCompletingNutrition ? "Uzupełniam..." : "Save",
                        systemImage: isCompletingNutrition ? "sparkles" : "checkmark",
                        isEnabled: hasRecognizedMeal && !isCompletingNutrition
                    ) {
                        Task { await saveAdjustedItems() }
                    }
                    Button(action: onRetake) {
                        Text("Try again")
                            .font(Tokens.Font.callout)
                            .foregroundStyle(Tokens.Palette.inkMuted)
                    }
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.top, Tokens.Space.md)
                .padding(.bottom, Tokens.Space.xl)
                .background(.ultraThinMaterial)
            }
        }
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
    }

    private var noMealHeardCard: some View {
        VStack(spacing: Tokens.Space.lg) {
            ZStack {
                Circle()
                    .fill(Tokens.Palette.warning.opacity(0.16))
                    .frame(width: 82, height: 82)
                Image(systemName: "waveform.badge.exclamationmark")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(Tokens.Palette.warning)
            }

            VStack(spacing: Tokens.Space.sm) {
                Text("Nie usłyszałem dania")
                    .font(Tokens.Font.title3)
                    .foregroundStyle(Tokens.Palette.ink)
                    .multilineTextAlignment(.center)
                Text("Powiedz nazwę jedzenia, np. „500 g ryżu i 200 g sera”. Dopiero wtedy pokażemy regulację gramów.")
                    .font(Tokens.Font.body)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: onRetake) {
                Label("Nagraj ponownie", systemImage: "mic.fill")
                    .font(Tokens.Font.bodyEmphasized)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Capsule().fill(Tokens.Palette.primary))
            }
            .buttonStyle(.pressable)
        }
        .padding(Tokens.Space.xl)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Tokens.Palette.surface.opacity(0.82))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(.white.opacity(0.48), lineWidth: 1)
        }
    }

    private var confirmationHeader: some View {
        HStack {
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Tokens.Palette.inkMuted)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial, in: Circle())
                    .background(Circle().fill(Tokens.Palette.surface.opacity(0.72)))
            }
            .buttonStyle(.pressable)
            .accessibilityLabel(Text("Close"))

            Spacer()
            Text("Review entry")
                .font(Tokens.Font.headline)
                .foregroundStyle(Tokens.Palette.ink)
            Spacer()
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, Tokens.Space.screenPadding)
        .padding(.top, Tokens.Space.lg)
        .padding(.bottom, Tokens.Space.md)
    }

    private var voiceSummaryHero: some View {
        HStack(spacing: Tokens.Space.lg) {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.white.opacity(0.18))
                    .frame(width: 72, height: 72)
                Image(systemName: "waveform")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Meal by voice")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.78))
                Text(String.localizedStringWithFormat(L("%lld kcal"), Int(adjustedCalories.rounded())))
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                Text(
                    String.localizedStringWithFormat(
                        L("%lld items · %lld g"),
                        adjustedItems.count,
                        Int(adjustedGrams.rounded())
                    )
                )
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.82))
            }
            Spacer(minLength: 0)
        }
        .padding(Tokens.Space.lg)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.86, green: 0.48, blue: 0.28),
                            Color(red: 0.56, green: 0.35, blue: 0.72),
                            Color(red: 0.18, green: 0.35, blue: 0.42),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(.white.opacity(0.20), lineWidth: 1)
        }
        .shadow(color: Color(red: 0.38, green: 0.22, blue: 0.35).opacity(0.24), radius: 24, y: 14)
    }

    private var transcriptCard: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            HStack {
                Text("What we heard")
                    .font(Tokens.Font.caption.weight(.semibold))
                    .foregroundStyle(Tokens.Palette.inkSubtle)
                    .textCase(.uppercase)
                Spacer()
                aiRefreshButton
            }
            TextEditor(text: $edited)
                .font(Tokens.Font.body)
                .foregroundStyle(Tokens.Palette.ink)
                .scrollContentBackground(.hidden)
                .focused($isTextInputFocused)
                .frame(minHeight: 96)
                .padding(Tokens.Space.md)
                .background(Tokens.Palette.surface.opacity(0.70), in: RoundedRectangle(cornerRadius: 20))
        }
        .padding(Tokens.Space.lg)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Tokens.Palette.surface.opacity(0.76))
        )
    }

    private var portionsCard: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            HStack {
                Text("Portions")
                    .font(Tokens.Font.headline)
                    .foregroundStyle(Tokens.Palette.ink)
                Spacer()
                Text(String.localizedStringWithFormat(L("%lld g"), Int(adjustedGrams.rounded())))
                    .font(Tokens.Font.footnote.weight(.bold))
                    .foregroundStyle(Tokens.Palette.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Tokens.Palette.primarySoft))
            }

            if portionMode == .overall {
                Text("Szczegóły są pod spodem, ale do dziennika trafi jedna pozycja.")
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Palette.inkMuted)
            } else {
                ForEach(Array(parsedRows.enumerated()), id: \.element.key) { index, row in
                    portionRow(row, index: index)
                    if index < parsedRows.count - 1 {
                        Divider().background(Tokens.Palette.separator)
                    }
                }
                addProductButton
            }
        }
        .padding(Tokens.Space.lg)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Tokens.Palette.surface.opacity(0.78))
        )
    }

    private var addProductButton: some View {
        Button {
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
        } label: {
            Label("Dodaj produkt", systemImage: "plus.circle.fill")
                .font(Tokens.Font.bodyEmphasized)
                .foregroundStyle(Tokens.Palette.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, Tokens.Space.xs)
        }
        .buttonStyle(.pressable)
    }

    private var modePicker: some View {
        PortionModeSelector(
            selection: $portionMode,
            totalLabel: L("Jedna pozycja z tekstu głosowego."),
            detailLabel: L("Produkty usłyszane osobno, z własnymi gramami."),
            detailCount: max(1, parsedRows.count)
        )
    }

    private var aiRefreshButton: some View {
        Button {
            isTextInputFocused = false
            Task { await refreshFromAI() }
        } label: {
            HStack(spacing: 5) {
                if isAnalyzingText {
                    ProgressView()
                        .controlSize(.mini)
                        .tint(Tokens.Palette.primary)
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .bold))
                }
                Text("Odśwież AI")
                    .font(Tokens.Font.caption.weight(.bold))
                AIQuotaBadge(remaining: mealAIRefreshRemaining)
            }
            .foregroundStyle(Tokens.Palette.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(Tokens.Palette.primarySoft))
        }
        .buttonStyle(.pressable)
        .disabled(isAnalyzingText || edited.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    private var mealAIRefreshRemaining: Int? {
        usageMeter?.remaining(.mealAIRefresh, cap: entitlementsStore?.current.mealAIRefreshesPerDay)
    }

    private var productNutritionRemaining: Int? {
        usageMeter?.remaining(.productNutritionLookup, cap: entitlementsStore?.current.productNutritionLookupsPerDay)
    }

    private func refreshFromAI() async {
        guard VoiceMealParser.hasRecognizableFoodText(edited) else {
            analyzedItems = []
            Haptics.warning()
            return
        }
        let suggested = VoiceFlowState.suggestedMealType(forHour: Calendar.current.component(.hour, from: Date()))
        let cap = entitlementsStore?.current.mealAIRefreshesPerDay
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
            usageMeter?.record(.mealAIRefresh, cap: cap)
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

    private var overallPortionCard: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                Text("Nazwa dania")
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                TextField("Risotto z krewetkami", text: $overallName)
                    .font(Tokens.Font.bodyEmphasized)
                    .textFieldStyle(.roundedBorder)
                    .focused($isTextInputFocused)
                    .submitLabel(.done)
                    .onSubmit { isTextInputFocused = false }
            }
            HStack {
                Text("Porcja")
                    .font(Tokens.Font.headline)
                    .foregroundStyle(Tokens.Palette.ink)
                Spacer()
                Text(String.localizedStringWithFormat(L("%lld g"), Int(overallGrams.rounded())))
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(Tokens.Palette.primary)
                    .contentTransition(.numericText())
            }
            Slider(value: $overallGrams, in: 10...1500, step: 5)
                .tint(Tokens.Palette.primary)
        }
        .padding(Tokens.Space.lg)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Tokens.Palette.surface.opacity(0.78))
        )
    }

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
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: Tokens.Space.xs) {
                TextField("Produkt", text: nameBinding)
                    .font(Tokens.Font.bodyEmphasized)
                    .textFieldStyle(.roundedBorder)
                    .focused($isTextInputFocused)
                    .submitLabel(.done)
                    .onSubmit { isTextInputFocused = false }
                Spacer(minLength: Tokens.Space.sm)
                productAIButton(for: row)
                if parsedRows.count > 1 {
                    Button {
                        analyzedItems.removeAll { $0.id == item.id }
                        grams.removeValue(forKey: row.key)
                        Haptics.selection()
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(Tokens.Palette.error)
                    }
                    .buttonStyle(.pressable)
                }
            }
            HStack {
                Text("\(Int((item.caloriesKcal * factor).rounded())) kcal")
                    .font(Tokens.Font.bodyEmphasized)
                    .foregroundStyle(Tokens.Palette.primary)
                    .contentTransition(.numericText())
                Spacer()
            }
            HStack {
                Text("\(Int(binding.wrappedValue.rounded())) g")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Tokens.Palette.ink)
                    .frame(width: 64, alignment: .leading)
                Slider(value: binding, in: 10...600, step: 5)
                    .tint(Tokens.Palette.primary)
            }
            Text(macroSummary(for: item, factor: factor))
                .font(Tokens.Font.caption)
                .foregroundStyle(Tokens.Palette.inkSubtle)
        }
        .padding(.vertical, Tokens.Space.xs)
    }

    private func productAIButton(for row: VoicePortionRow) -> some View {
        Button {
            isTextInputFocused = false
            Task { await refreshProductNutrition(row) }
        } label: {
            HStack(spacing: 4) {
                if productLookupsInFlight.contains(row.key) {
                    ProgressView()
                        .controlSize(.mini)
                        .tint(Tokens.Palette.primary)
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .bold))
                }
                AIQuotaBadge(remaining: productNutritionRemaining)
            }
        }
        .frame(minWidth: 30, minHeight: 30)
        .foregroundStyle(Tokens.Palette.primary)
        .background(Circle().fill(Tokens.Palette.primarySoft))
        .buttonStyle(.pressable)
        .disabled(
            productLookupsInFlight.contains(row.key)
                || mealAnalyzer == nil
                || row.item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        )
        .accessibilityLabel(Text("Uzupełnij produkt AI"))
    }

    private func refreshProductNutrition(_ row: VoicePortionRow) async {
        guard let mealAnalyzer else { return }
        let currentGrams = grams[row.key] ?? row.item.quantityGrams
        guard currentGrams > 0, !row.item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let cap = entitlementsStore?.current.productNutritionLookupsPerDay
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
        let completed = await mealAnalyzer.complete(item: draft, mealType: suggested)
        usageMeter?.record(.productNutritionLookup, cap: cap)
        if let index = parsedRows.firstIndex(where: { $0.key == row.key }) {
            analyzedItems[index] = FoodItem(
                id: row.item.id,
                name: completed.item.name,
                quantityGrams: completed.item.quantityGrams,
                caloriesKcal: completed.item.caloriesKcal,
                proteinGrams: completed.item.proteinGrams,
                carbsGrams: completed.item.carbsGrams,
                fatGrams: completed.item.fatGrams,
                fiberGrams: completed.item.fiberGrams,
                catalogFoodID: completed.item.catalogFoodID,
                confidence: completed.item.confidence
            )
            grams[row.key] = completed.item.quantityGrams
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
        let missingCount = items.filter(Self.needsNutrition).count
        guard missingCount > 0 else { return 0 }
        return portionMode == .overall ? 1 : missingCount
    }

    private func canConsumeAICompletion(count: Int) -> Bool {
        guard count > 0 else { return true }
        let kind: UsageMeter.Kind = portionMode == .overall ? .mealAIRefresh : .productNutritionLookup
        let cap =
            portionMode == .overall
            ? entitlementsStore?.current.mealAIRefreshesPerDay
            : entitlementsStore?.current.productNutritionLookupsPerDay
        guard let cap, let usageMeter else { return true }
        if usageMeter.used(kind) + count <= cap { return true }
        Haptics.light()
        paywallCoordinator?.present(portionMode == .overall ? .mealAIRefreshQuota : .productNutritionQuota)
        return false
    }

    private func recordAICompletion(count: Int) {
        guard count > 0 else { return }
        let kind: UsageMeter.Kind = portionMode == .overall ? .mealAIRefresh : .productNutritionLookup
        let cap =
            portionMode == .overall
            ? entitlementsStore?.current.mealAIRefreshesPerDay
            : entitlementsStore?.current.productNutritionLookupsPerDay
        for _ in 0..<count {
            usageMeter?.record(kind, cap: cap)
        }
    }

    private static func needsNutrition(_ item: FoodItem) -> Bool {
        item.caloriesKcal <= 0 || item.proteinGrams <= 0 || item.carbsGrams <= 0 || item.fatGrams <= 0
    }
}

private struct VoicePortionRow: Identifiable {
    let key: String
    let item: FoodItem

    var id: String { key }
}
