import OSLog
import SwiftUI

// MARK: - Shared sheet chrome

private struct GoalSheetScaffold<Content: View>: View {
    let title: String
    let onCancel: () -> Void
    let onSave: () -> Void
    let saveDisabled: Bool
    @ViewBuilder var content: () -> Content

    init(
        title: String,
        onCancel: @escaping () -> Void,
        onSave: @escaping () -> Void,
        saveDisabled: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.onCancel = onCancel
        self.onSave = onSave
        self.saveDisabled = saveDisabled
        self.content = content
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Tokens.Palette.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: Tokens.Space.lg) {
                        content()
                    }
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.vertical, Tokens.Space.lg)
                }
            }
            .navigationTitle(Text(title))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Anuluj", action: onCancel)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Zapisz", action: onSave).disabled(saveDisabled)
                }
            }
        }
    }
}

// MARK: - Weight quick update

struct QuickWeightUpdateSheet: View {
    let user: User
    let service: UserProfileService
    let onDismiss: () -> Void

    @State private var weightKg: Double
    @State private var note: String = ""

    init(user: User, service: UserProfileService, onDismiss: @escaping () -> Void) {
        self.user = user
        self.service = service
        self.onDismiss = onDismiss
        self._weightKg = State(initialValue: user.weightKg ?? 70)
    }

    var body: some View {
        GoalSheetScaffold(
            title: "Aktualizuj wagę",
            onCancel: onDismiss,
            onSave: save
        ) {
            Card {
                VStack(spacing: Tokens.Space.md) {
                    Text(String(format: "%.1f kg", weightKg).replacingOccurrences(of: ".", with: ","))
                        .font(Tokens.Font.title)
                        .foregroundStyle(Tokens.Palette.ink)
                    Slider(value: $weightKg, in: 30...250, step: 0.1)
                }
            }
            Card {
                TextField("Notatka (opcjonalnie)", text: $note, axis: .vertical)
                    .lineLimit(2...4)
            }
            Text("Twoja waga zaktualizuje się w profilu, a my przeliczymy normy dzienne (jeśli nie są zablokowane).")
                .font(Tokens.Font.footnote)
                .foregroundStyle(Tokens.Palette.inkMuted)
        }
    }

    private func save() {
        do {
            try service.updateWeight(weightKg, note: note.isEmpty ? nil : note)
            Haptics.success()
            onDismiss()
        } catch {
            Logger.persistence.error("Weight update failed: \(String(describing: error))")
        }
    }
}

// MARK: - Activity level

struct EditActivitySheet: View {
    let user: User
    let service: UserProfileService
    let onDismiss: () -> Void

    @State private var selected: ActivityLevel

    init(user: User, service: UserProfileService, onDismiss: @escaping () -> Void) {
        self.user = user
        self.service = service
        self.onDismiss = onDismiss
        self._selected = State(initialValue: user.activityLevel)
    }

    private var previewKcal: Int {
        guard let h = user.heightCm,
            let w = user.weightKg,
            let birth = user.birthDate
        else { return user.dailyCalorieGoalKcal }
        let age = Calendar.current.dateComponents([.year], from: birth, to: Date()).year ?? 0
        let input = GoalCalculator.Input(
            heightCm: h, weightKg: w, age: age,
            biologicalSex: user.biologicalSex,
            activityLevel: selected,
            goal: user.goalKind,
            paceKgPerWeek: user.goalPaceKgPerWeek
        )
        return GoalCalculator.calculateTargets(from: input)?.dailyCalorieGoalKcal
            ?? user.dailyCalorieGoalKcal
    }

    var body: some View {
        GoalSheetScaffold(
            title: "Aktywność",
            onCancel: onDismiss,
            onSave: save
        ) {
            VStack(spacing: Tokens.Space.md) {
                ForEach(ActivityLevel.allCases, id: \.self) { level in
                    OnboardingChoiceCard(
                        symbol: symbol(for: level),
                        title: LocalizedStringKey(title(for: level)),
                        subtitle: LocalizedStringKey(subtitle(for: level)),
                        isSelected: selected == level,
                        action: { selected = level }
                    )
                }
            }
            if !user.caloriesOverridden {
                Card(background: Tokens.Palette.primarySoft) {
                    HStack {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(Tokens.Palette.primary)
                        Text("Norma zmieni się: \(user.dailyCalorieGoalKcal) → \(previewKcal) kcal")
                            .font(Tokens.Font.body)
                            .foregroundStyle(Tokens.Palette.ink)
                    }
                }
            }
        }
    }

    private func save() {
        try? service.updateActivityLevel(selected)
        Haptics.light()
        onDismiss()
    }

    private func symbol(for l: ActivityLevel) -> String {
        switch l {
        case .sedentary: return "chair.fill"
        case .light: return "figure.walk"
        case .moderate: return "figure.run"
        case .active: return "figure.strengthtraining.traditional"
        case .veryActive: return "flame.fill"
        }
    }

    private func title(for l: ActivityLevel) -> String {
        switch l {
        case .sedentary: return "Siedzący"
        case .light: return "Lekko aktywny"
        case .moderate: return "Umiarkowanie aktywny"
        case .active: return "Aktywny"
        case .veryActive: return "Bardzo aktywny"
        }
    }

    private func subtitle(for l: ActivityLevel) -> String {
        switch l {
        case .sedentary: return "Biuro, niewiele ruchu"
        case .light: return "Ćwiczenia 1-3× w tygodniu"
        case .moderate: return "Ćwiczenia 3-5× w tygodniu"
        case .active: return "Treningi 5-6× w tygodniu"
        case .veryActive: return "Intensywne 6-7× w tygodniu"
        }
    }
}

// MARK: - Calorie override

struct EditCaloriesSheet: View {
    let user: User
    let service: UserProfileService
    let onDismiss: () -> Void

    @State private var kcal: Int

    init(user: User, service: UserProfileService, onDismiss: @escaping () -> Void) {
        self.user = user
        self.service = service
        self.onDismiss = onDismiss
        self._kcal = State(initialValue: user.dailyCalorieGoalKcal)
    }

    var body: some View {
        GoalSheetScaffold(
            title: "Cel kaloryczny",
            onCancel: onDismiss,
            onSave: {
                try? service.overrideCalories(kcal)
                Haptics.light()
                onDismiss()
            }
        ) {
            Card {
                VStack(spacing: Tokens.Space.md) {
                    Text("\(kcal) kcal")
                        .font(Tokens.Font.title)
                    Slider(
                        value: Binding(
                            get: { Double(kcal) },
                            set: { kcal = Int($0) }
                        ),
                        in: 1000...4500, step: 25
                    )
                }
            }
            Button("Wróć do zalecanych") {
                try? service.resetTargetsToRecommended()
                Haptics.light()
                onDismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(Tokens.Palette.primary)
        }
    }
}

// MARK: - Macro override

struct EditMacrosSheet: View {
    let user: User
    let service: UserProfileService
    let onDismiss: () -> Void

    @State private var proteinPct: Double
    @State private var fatPct: Double

    init(user: User, service: UserProfileService, onDismiss: @escaping () -> Void) {
        self.user = user
        self.service = service
        self.onDismiss = onDismiss
        let kcal = max(1, Double(user.dailyCalorieGoalKcal))
        let proteinKcal = Double(user.proteinGoalGrams) * 4
        let fatKcal = Double(user.fatGoalGrams) * 9
        self._proteinPct = State(initialValue: proteinKcal / kcal)
        self._fatPct = State(initialValue: fatKcal / kcal)
    }

    private var carbsPct: Double {
        max(0.0, 1.0 - proteinPct - fatPct)
    }

    private var proteinGrams: Int {
        Int((Double(user.dailyCalorieGoalKcal) * proteinPct / 4).rounded())
    }

    private var fatGrams: Int {
        Int((Double(user.dailyCalorieGoalKcal) * fatPct / 9).rounded())
    }

    private var carbsGrams: Int {
        Int((Double(user.dailyCalorieGoalKcal) * carbsPct / 4).rounded())
    }

    var body: some View {
        GoalSheetScaffold(
            title: "Makroskładniki",
            onCancel: onDismiss,
            onSave: {
                try? service.overrideMacros(
                    protein: proteinGrams,
                    carbs: carbsGrams,
                    fat: fatGrams
                )
                Haptics.light()
                onDismiss()
            }
        ) {
            Card {
                VStack(alignment: .leading, spacing: Tokens.Space.md) {
                    macroSlider(symbol: "💪", label: "Białko", pct: $proteinPct, grams: proteinGrams)
                    macroSlider(symbol: "🥑", label: "Tłuszcze", pct: $fatPct, grams: fatGrams)
                    HStack {
                        Text("🍞 Węglowodany").foregroundStyle(Tokens.Palette.ink)
                        Spacer()
                        Text("\(carbsGrams) g (\(Int(carbsPct * 100))%)")
                            .foregroundStyle(Tokens.Palette.inkMuted)
                    }
                    .font(Tokens.Font.body)
                }
            }
            if proteinPct + fatPct > 0.85 {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Tokens.Palette.warning)
                    Text("Za mało węglowodanów. Zostaw przynajmniej 15% na energię.")
                        .font(Tokens.Font.footnote)
                }
            }
            Button("Wróć do zalecanych") {
                try? service.resetTargetsToRecommended()
                Haptics.light()
                onDismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(Tokens.Palette.primary)
        }
    }

    private func macroSlider(
        symbol: String,
        label: String,
        pct: Binding<Double>,
        grams: Int
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("\(symbol) \(label)")
                Spacer()
                Text("\(grams) g (\(Int(pct.wrappedValue * 100))%)")
                    .foregroundStyle(Tokens.Palette.inkMuted)
            }
            .font(Tokens.Font.body)
            Slider(value: pct, in: 0.10...0.50, step: 0.01)
        }
    }
}

// MARK: - Water override

struct EditWaterSheet: View {
    let user: User
    let service: UserProfileService
    let onDismiss: () -> Void

    @State private var waterMl: Int

    init(user: User, service: UserProfileService, onDismiss: @escaping () -> Void) {
        self.user = user
        self.service = service
        self.onDismiss = onDismiss
        self._waterMl = State(initialValue: user.waterGoalMl)
    }

    var body: some View {
        GoalSheetScaffold(
            title: "Cel wody",
            onCancel: onDismiss,
            onSave: {
                try? service.overrideWater(waterMl)
                Haptics.light()
                onDismiss()
            }
        ) {
            Card {
                VStack(spacing: Tokens.Space.md) {
                    Text("\(waterMl) ml")
                        .font(Tokens.Font.title)
                    Slider(
                        value: Binding(
                            get: { Double(waterMl) },
                            set: { waterMl = Int(($0 / 50).rounded()) * 50 }
                        ),
                        in: 1000...5000, step: 50
                    )
                }
            }
            Button("Wróć do zalecanych") {
                try? service.resetTargetsToRecommended()
                Haptics.light()
                onDismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(Tokens.Palette.primary)
        }
    }
}

// MARK: - Main goal

struct EditMainGoalSheet: View {
    let user: User
    let service: UserProfileService
    let onDismiss: () -> Void

    @State private var kind: GoalKind
    @State private var paceKgPerWeek: Double
    @State private var targetWeightKg: Double

    init(user: User, service: UserProfileService, onDismiss: @escaping () -> Void) {
        self.user = user
        self.service = service
        self.onDismiss = onDismiss
        self._kind = State(initialValue: user.goalKind)
        self._paceKgPerWeek = State(initialValue: user.goalPaceKgPerWeek ?? 0.5)
        let fallbackTarget = (user.weightKg ?? 70)
            - (user.goalKind == .lose ? 5 : (user.goalKind == .gain ? -5 : 0))
        self._targetWeightKg = State(initialValue: user.goalTargetWeightKg ?? fallbackTarget)
    }

    var body: some View {
        GoalSheetScaffold(
            title: "Twój cel",
            onCancel: onDismiss,
            onSave: {
                try? service.updateMainGoal(
                    kind: kind,
                    paceKgPerWeek: kind.requiresPaceAndTarget ? paceKgPerWeek : nil,
                    targetWeightKg: kind.requiresPaceAndTarget ? targetWeightKg : nil
                )
                Haptics.success()
                onDismiss()
            }
        ) {
            VStack(spacing: Tokens.Space.md) {
                ForEach(GoalKind.allCases, id: \.self) { option in
                    OnboardingChoiceCard(
                        symbol: symbol(for: option),
                        title: LocalizedStringKey(title(for: option)),
                        subtitle: LocalizedStringKey(subtitle(for: option)),
                        isSelected: kind == option,
                        action: { kind = option }
                    )
                }
            }
            if kind.requiresPaceAndTarget {
                Card {
                    VStack(alignment: .leading, spacing: Tokens.Space.md) {
                        HStack {
                            Text("Docelowa waga")
                                .foregroundStyle(Tokens.Palette.inkMuted)
                            Spacer()
                            Text(String(format: "%.1f kg", targetWeightKg))
                        }
                        Slider(value: $targetWeightKg, in: 40...180, step: 0.5)
                        HStack {
                            Text("Tempo")
                                .foregroundStyle(Tokens.Palette.inkMuted)
                            Spacer()
                            Text(String(format: "%.2f kg / tydz.", paceKgPerWeek))
                        }
                        Slider(value: $paceKgPerWeek, in: 0.25...1.0, step: 0.25)
                    }
                }
            }
        }
    }

    private func symbol(for goal: GoalKind) -> String {
        switch goal {
        case .lose: return "arrow.down.right"
        case .gain: return "arrow.up.right"
        case .maintain: return "equal"
        case .healthCondition: return "heart.text.square"
        case .justTracking: return "magnifyingglass"
        }
    }

    private func title(for goal: GoalKind) -> String {
        switch goal {
        case .lose: return "Schudnąć"
        case .gain: return "Nabrać masy"
        case .maintain: return "Utrzymać wagę"
        case .healthCondition: return "Cel zdrowotny"
        case .justTracking: return "Tylko śledzenie"
        }
    }

    private func subtitle(for goal: GoalKind) -> String {
        switch goal {
        case .lose: return "Łagodny deficyt"
        case .gain: return "Większa porcja energii"
        case .maintain: return "Bez zmiany masy"
        case .healthCondition: return "Plan zdrowotny / dietetyk"
        case .justTracking: return "Po prostu loguj"
        }
    }
}

// MARK: - Profile data (sex / age / height)

struct EditProfileDataSheet: View {
    let user: User
    let service: UserProfileService
    let onDismiss: () -> Void

    @State private var sex: BiologicalSex
    @State private var heightCm: Int
    @State private var birthDate: Date

    @Environment(\.modelContext) private var modelContext

    init(user: User, service: UserProfileService, onDismiss: @escaping () -> Void) {
        self.user = user
        self.service = service
        self.onDismiss = onDismiss
        self._sex = State(initialValue: user.biologicalSex)
        self._heightCm = State(initialValue: user.heightCm ?? 170)
        self._birthDate = State(
            initialValue: user.birthDate
                ?? Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date()
        )
    }

    var body: some View {
        GoalSheetScaffold(
            title: "Twoje dane",
            onCancel: onDismiss,
            onSave: save
        ) {
            Card {
                VStack(spacing: Tokens.Space.md) {
                    HStack {
                        Text("Płeć").foregroundStyle(Tokens.Palette.inkMuted)
                        Spacer()
                        Picker("Płeć", selection: $sex) {
                            Text("Kobieta").tag(BiologicalSex.female)
                            Text("Mężczyzna").tag(BiologicalSex.male)
                            Text("Wolę nie podawać").tag(BiologicalSex.undisclosed)
                        }
                        .pickerStyle(.menu)
                    }
                    HStack {
                        Text("Wzrost").foregroundStyle(Tokens.Palette.inkMuted)
                        Spacer()
                        Stepper(value: $heightCm, in: 130...220, step: 1) {
                            Text("\(heightCm) cm")
                        }
                    }
                    DatePicker(
                        "Data urodzenia",
                        selection: $birthDate,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                }
            }
        }
    }

    private func save() {
        // Direct mutation — these aren't behind a service method yet.
        user.biologicalSex = sex
        user.heightCm = heightCm
        user.birthDate = birthDate
        user.updatedAt = Date()
        try? modelContext.save()
        try? service.resetTargetsToRecommended()
        Haptics.light()
        onDismiss()
    }
}
