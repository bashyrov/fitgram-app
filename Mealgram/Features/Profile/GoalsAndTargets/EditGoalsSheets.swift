import OSLog
import SwiftUI

// swiftlint:disable file_length

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
        guard let height = user.heightCm,
            let weight = user.weightKg,
            let birth = user.birthDate
        else { return user.dailyCalorieGoalKcal }
        let age = Calendar.current.dateComponents([.year], from: birth, to: Date()).year ?? 0
        let input = GoalCalculator.Input(
            heightCm: height, weightKg: weight, age: age,
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

    private func symbol(for level: ActivityLevel) -> String {
        switch level {
        case .sedentary: return "chair.fill"
        case .light: return "figure.walk"
        case .moderate: return "figure.run"
        case .active: return "figure.strengthtraining.traditional"
        case .veryActive: return "flame.fill"
        }
    }

    private func title(for level: ActivityLevel) -> String {
        switch level {
        case .sedentary: return String(localized: "Siedzący")
        case .light: return String(localized: "Lekko aktywny")
        case .moderate: return String(localized: "Umiarkowanie aktywny")
        case .active: return String(localized: "Aktywny")
        case .veryActive: return String(localized: "Bardzo aktywny")
        }
    }

    private func subtitle(for level: ActivityLevel) -> String {
        switch level {
        case .sedentary: return String(localized: "Biuro, niewiele ruchu")
        case .light: return String(localized: "Ćwiczenia 1-3× w tygodniu")
        case .moderate: return String(localized: "Ćwiczenia 3-5× w tygodniu")
        case .active: return String(localized: "Treningi 5-6× w tygodniu")
        case .veryActive: return String(localized: "Intensywne 6-7× w tygodniu")
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

    private func save() {
        try? service.overrideCalories(kcal)
        Haptics.light()
        onDismiss()
    }

    var body: some View {
        GoalSheetScaffold(
            title: "Cel kaloryczny",
            onCancel: onDismiss,
            onSave: save
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

    private func save() {
        try? service.overrideMacros(
            protein: proteinGrams,
            carbs: carbsGrams,
            fat: fatGrams
        )
        Haptics.light()
        onDismiss()
    }

    var body: some View {
        GoalSheetScaffold(
            title: "Makroskładniki",
            onCancel: onDismiss,
            onSave: save
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

    private func save() {
        try? service.overrideWater(waterMl)
        Haptics.light()
        onDismiss()
    }

    var body: some View {
        GoalSheetScaffold(
            title: "Cel wody",
            onCancel: onDismiss,
            onSave: save
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

    private func save() {
        try? service.updateMainGoal(
            kind: kind,
            paceKgPerWeek: kind.requiresPaceAndTarget ? paceKgPerWeek : nil,
            targetWeightKg: kind.requiresPaceAndTarget ? targetWeightKg : nil
        )
        Haptics.success()
        onDismiss()
    }

    var body: some View {
        GoalSheetScaffold(
            title: "Twój cel",
            onCancel: onDismiss,
            onSave: save
        ) {
            goalHero
            VStack(spacing: Tokens.Space.md) {
                ForEach(GoalKind.allCases, id: \.self) { option in
                    OnboardingChoiceCard(
                        symbol: symbol(for: option),
                        title: LocalizedStringKey(title(for: option)),
                        subtitle: LocalizedStringKey(subtitle(for: option)),
                        isSelected: kind == option,
                        action: {
                            Haptics.selection()
                            kind = option
                        }
                    )
                }
            }
            if kind.requiresPaceAndTarget {
                journeyCard
                paceCard
                if paceKgPerWeek >= 0.75 {
                    paceWarningStrip
                }
            }
        }
    }

    // MARK: - Hero header

    /// Big gradient header showing the chosen goal's icon + label so the
    /// sheet doesn't open with a wall of generic-looking selection rows.
    private var goalHero: some View {
        let tint = heroTint(for: kind)
        return Card(elevation: Tokens.Shadow.float) {
            HStack(spacing: Tokens.Space.lg) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [tint, tint.opacity(0.55)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 64, height: 64)
                        .shadow(color: tint.opacity(0.4), radius: 12, y: 6)
                    Image(systemName: symbol(for: kind))
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Twój cel")
                        .font(Tokens.Font.caption)
                        .textCase(.uppercase)
                        .tracking(1.2)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                    Text(LocalizedStringKey(title(for: kind)))
                        .font(Tokens.Font.title2)
                        .foregroundStyle(Tokens.Palette.ink)
                    Text(LocalizedStringKey(subtitle(for: kind)))
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func heroTint(for kind: GoalKind) -> Color {
        switch kind {
        case .lose: return Tokens.Palette.primary
        case .gain: return Tokens.Palette.warning
        case .maintain: return Tokens.Palette.success
        case .healthCondition: return Tokens.Palette.accent
        case .justTracking: return Tokens.Palette.inkMuted
        }
    }

    // MARK: - Journey card (current → target)

    /// Visualises the trip the user is signing up for: current weight on
    /// the left, target on the right, with a chevron between them, a
    /// target-weight slider underneath, and a delta chip showing how
    /// much weight is being lost/gained.
    private var journeyCard: some View {
        let current = user.weightKg ?? targetWeightKg
        let delta = abs(targetWeightKg - current)
        return Card {
            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                HStack(spacing: 4) {
                    Image(systemName: "scalemass.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Tokens.Palette.primary)
                    Text("Twoja droga")
                        .font(Tokens.Font.headline)
                        .foregroundStyle(Tokens.Palette.ink)
                    Spacer()
                    Text(String(format: "%@%.1f kg", deltaSign(), delta))
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule().fill(heroTint(for: kind))
                        )
                }
                HStack(alignment: .center, spacing: Tokens.Space.md) {
                    journeyPillar(label: "Teraz", value: current, tint: Tokens.Palette.inkMuted)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Tokens.Palette.inkSubtle)
                    journeyPillar(label: "Cel", value: targetWeightKg, tint: heroTint(for: kind))
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Docelowa waga")
                            .font(Tokens.Font.caption)
                            .foregroundStyle(Tokens.Palette.inkMuted)
                        Spacer()
                        Text(String(format: "%.1f kg", targetWeightKg))
                            .font(Tokens.Font.bodyEmphasized)
                            .foregroundStyle(Tokens.Palette.ink)
                            .contentTransition(.numericText())
                    }
                    Slider(value: $targetWeightKg, in: 40...180, step: 0.5) { editing in
                        if editing { Haptics.selection() }
                    }
                    .tint(heroTint(for: kind))
                }
            }
        }
    }

    private func journeyPillar(label: LocalizedStringKey, value: Double, tint: Color) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(Tokens.Font.caption)
                .foregroundStyle(Tokens.Palette.inkMuted)
            Text(String(format: "%.1f", value))
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(tint)
            Text("kg")
                .font(Tokens.Font.caption)
                .foregroundStyle(Tokens.Palette.inkMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Tokens.Space.sm)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                .fill(tint.opacity(0.10))
        )
    }

    private func deltaSign() -> String {
        switch kind {
        case .lose: return "−"
        case .gain: return "+"
        default: return ""
        }
    }

    // MARK: - Pace card

    private var paceCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                HStack(spacing: 6) {
                    Image(systemName: "speedometer")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Tokens.Palette.warning)
                    Text("Tempo")
                        .font(Tokens.Font.headline)
                        .foregroundStyle(Tokens.Palette.ink)
                    Spacer()
                    Text(String(format: "%.2f kg / tydz.", paceKgPerWeek))
                        .font(Tokens.Font.bodyEmphasized)
                        .foregroundStyle(Tokens.Palette.ink)
                        .contentTransition(.numericText())
                }
                Slider(value: $paceKgPerWeek, in: 0.25...1.0, step: 0.25) { editing in
                    if editing { Haptics.selection() }
                }
                .tint(paceTint)
                HStack(spacing: 6) {
                    Text("Wolniej · bezpieczniej")
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                    Spacer()
                    Text("Szybciej · intensywniej")
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                }
                if let estimatedEnd = estimatedEndDate {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Tokens.Palette.primary)
                        Text("Szacowany koniec: ")
                            .font(Tokens.Font.caption)
                            .foregroundStyle(Tokens.Palette.inkMuted)
                            + Text(estimatedEnd.formatted(.dateTime.day().month(.wide).year()))
                                .font(Tokens.Font.caption)
                                .foregroundStyle(Tokens.Palette.ink)
                    }
                    .padding(.top, 2)
                }
            }
        }
    }

    private var paceTint: Color {
        switch paceKgPerWeek {
        case ..<0.5: return Tokens.Palette.success
        case 0.5..<0.75: return Tokens.Palette.warning
        default: return Tokens.Palette.error
        }
    }

    private var estimatedEndDate: Date? {
        guard let current = user.weightKg, paceKgPerWeek > 0 else { return nil }
        return GoalProjection.estimatedEndDate(
            currentWeightKg: current,
            targetWeightKg: targetWeightKg,
            paceKgPerWeek: paceKgPerWeek
        )
    }

    private var paceWarningStrip: some View {
        HStack(alignment: .top, spacing: Tokens.Space.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Tokens.Palette.error)
            Text("To bardzo intensywne tempo. Trwałe rezultaty przy 0,25-0,5 kg/tydzień. Skonsultuj z dietetykiem.")
                .font(Tokens.Font.footnote)
                .foregroundStyle(Tokens.Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(Tokens.Space.md)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                .fill(Tokens.Palette.error.opacity(0.10))
        )
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
        case .lose: return String(localized: "Schudnąć")
        case .gain: return String(localized: "Nabrać masy")
        case .maintain: return String(localized: "Utrzymać wagę")
        case .healthCondition: return String(localized: "Cel zdrowotny")
        case .justTracking: return String(localized: "Tylko śledzenie")
        }
    }

    private func subtitle(for goal: GoalKind) -> String {
        switch goal {
        case .lose: return String(localized: "Łagodny deficyt")
        case .gain: return String(localized: "Większa porcja energii")
        case .maintain: return String(localized: "Bez zmiany masy")
        case .healthCondition: return String(localized: "Plan zdrowotny / dietetyk")
        case .justTracking: return String(localized: "Po prostu loguj")
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
