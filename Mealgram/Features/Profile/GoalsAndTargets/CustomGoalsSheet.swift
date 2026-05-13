import OSLog
import SwiftUI

/// Profile entry point for the multi-goal system. Lists active +
/// historical CustomGoal rows with their progress bars, and lets the
/// user create new ones (up to GoalsService.maxActiveGoals).
struct CustomGoalsSheet: View {
    let goalsService: GoalsService
    let userRemoteID: String
    let onDismiss: () -> Void

    @State private var goals: [CustomGoal] = []
    @State private var isBuilderPresented: Bool = false
    @State private var feedback: String?

    private var activeCount: Int {
        goals.filter { $0.status == .active }.count
    }

    private var canCreate: Bool {
        activeCount < GoalsService.maxActiveGoals
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Tokens.Palette.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: Tokens.Space.md) {
                        if goals.isEmpty {
                            emptyCard
                        } else {
                            ForEach(goals) { goal in
                                CustomGoalRowCard(
                                    goal: goal,
                                    progress: progress(for: goal),
                                    onComplete: { complete(goal) },
                                    onAbandon: { abandon(goal) },
                                    onDelete: { delete(goal) }
                                )
                            }
                        }
                        Button {
                            if canCreate {
                                isBuilderPresented = true
                            } else {
                                feedback = "Maks. \(GoalsService.maxActiveGoals) aktywne cele jednocześnie."
                            }
                        } label: {
                            Label("Nowy cel", systemImage: "plus.circle.fill")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: Tokens.Radius.lg)
                                        .fill(canCreate ? Tokens.Palette.primary : Tokens.Palette.surfaceMuted)
                                )
                                .foregroundStyle(canCreate ? .white : Tokens.Palette.inkMuted)
                        }
                        if let feedback {
                            Text(feedback)
                                .font(Tokens.Font.footnote)
                                .foregroundStyle(Tokens.Palette.error)
                        }
                    }
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.vertical, Tokens.Space.lg)
                }
            }
            .navigationTitle(Text("Dodatkowe cele"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Gotowe", action: onDismiss)
                }
            }
            .sheet(isPresented: $isBuilderPresented) {
                CustomGoalBuilderSheet(userRemoteID: userRemoteID, goalsService: goalsService) {
                    isBuilderPresented = false
                    reload()
                }
            }
            .task { reload() }
        }
    }

    private var emptyCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                Text("Brak dodatkowych celów")
                    .font(Tokens.Font.headline)
                Text(
                    "Dodaj cel jak \"Maraton w czerwcu\" albo \"Bez fast-food przez 30 dni\" — Mealgram pomoże Ci go pilnować."
                )
                .font(Tokens.Font.footnote)
                .foregroundStyle(Tokens.Palette.inkMuted)
            }
        }
    }

    private func progress(for goal: CustomGoal) -> Double {
        (try? goalsService.progress(for: goal)) ?? 0
    }

    private func reload() {
        goals = (try? goalsService.allGoals()) ?? []
    }

    private func complete(_ goal: CustomGoal) {
        try? goalsService.updateStatus(id: goal.id, .completed)
        Haptics.success()
        reload()
    }

    private func abandon(_ goal: CustomGoal) {
        try? goalsService.updateStatus(id: goal.id, .abandoned)
        Haptics.warning()
        reload()
    }

    private func delete(_ goal: CustomGoal) {
        try? goalsService.delete(id: goal.id)
        Haptics.warning()
        reload()
    }
}

struct CustomGoalRowCard: View {
    let goal: CustomGoal
    let progress: Double
    let onComplete: () -> Void
    let onAbandon: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                HStack {
                    Text(goal.name)
                        .font(Tokens.Font.headline)
                        .foregroundStyle(Tokens.Palette.ink)
                    Spacer()
                    statusChip
                }
                Text(dateRange)
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                ProgressView(value: progress)
                    .tint(Tokens.Palette.primary)
                ForEach(goal.targets) { target in
                    HStack(spacing: 6) {
                        Image(systemName: symbol(for: target.type))
                            .foregroundStyle(Tokens.Palette.primary)
                        Text(targetSummary(target))
                            .font(Tokens.Font.footnote)
                            .foregroundStyle(Tokens.Palette.inkMuted)
                    }
                }
                if goal.status == .active {
                    HStack {
                        Button("Ukończ") { onComplete() }
                            .buttonStyle(.bordered)
                            .tint(Tokens.Palette.primary)
                        Button("Porzuć") { onAbandon() }
                            .buttonStyle(.bordered)
                            .tint(Tokens.Palette.warning)
                        Spacer()
                        Button(role: .destructive) {
                            onDelete()
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.bordered)
                    }
                    .font(Tokens.Font.caption)
                }
            }
        }
    }

    private var statusChip: some View {
        Text(statusLabel)
            .font(Tokens.Font.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(statusColor.opacity(0.18))
            )
            .foregroundStyle(statusColor)
    }

    private var statusLabel: String {
        switch goal.status {
        case .active: return "Aktywny"
        case .completed: return "Ukończony"
        case .abandoned: return "Porzucony"
        case .paused: return "Wstrzymany"
        }
    }

    private var statusColor: Color {
        switch goal.status {
        case .active: return Tokens.Palette.primary
        case .completed: return Tokens.Palette.success
        case .abandoned: return Tokens.Palette.inkMuted
        case .paused: return Tokens.Palette.warning
        }
    }

    private var dateRange: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return "\(formatter.string(from: goal.startDate)) → \(formatter.string(from: goal.endDate))"
    }

    private func symbol(for type: CustomGoalTarget.TargetType) -> String {
        switch type {
        case .weightLoss: return "arrow.down.right"
        case .weightGain: return "arrow.up.right"
        case .proteinDaily: return "dumbbell.fill"
        case .waterDaily: return "drop.fill"
        case .noFastFoodDays: return "hand.raised.fill"
        case .maxCaloriesDaily: return "flame.fill"
        case .custom: return "star.fill"
        }
    }

    private func targetSummary(_ target: CustomGoalTarget) -> String {
        let valueStr: String = {
            if target.value.truncatingRemainder(dividingBy: 1) == 0 {
                return String(format: "%.0f", target.value)
            } else {
                return String(format: "%.1f", target.value).replacingOccurrences(of: ".", with: ",")
            }
        }()
        switch target.type {
        case .weightLoss: return "Schudnąć \(valueStr) kg"
        case .weightGain: return "Nabrać \(valueStr) kg"
        case .proteinDaily: return "\(valueStr) g białka dziennie"
        case .waterDaily: return "\(valueStr) ml wody dziennie"
        case .noFastFoodDays: return "\(valueStr) dni bez fast-food"
        case .maxCaloriesDaily: return "Max \(valueStr) kcal dziennie"
        case .custom: return "\(target.customName ?? "Cel"): \(valueStr)"
        }
    }
}

/// Multi-step builder for a new custom goal.
struct CustomGoalBuilderSheet: View {
    let userRemoteID: String
    let goalsService: GoalsService
    let onSaved: () -> Void

    @State private var name: String = ""
    @State private var durationWeeks: Int = 8
    @State private var customEndDate: Date = Calendar.current.date(byAdding: .weekOfYear, value: 8, to: Date()) ?? Date()
    @State private var useCustomDate: Bool = false
    @State private var selected: Set<CustomGoalTarget.TargetType> = []
    @State private var values: [CustomGoalTarget.TargetType: Double] = [:]
    @State private var customName: String = ""
    @State private var reminder: CustomGoalReminder? = .weekly
    @State private var error: String?

    @Environment(\.dismiss) private var dismiss

    private var endDate: Date {
        useCustomDate
            ? customEndDate
            : Calendar.current.date(byAdding: .weekOfYear, value: durationWeeks, to: Date()) ?? Date()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Tokens.Palette.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: Tokens.Space.lg) {
                        Card {
                            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                                Text("Nazwa")
                                    .font(Tokens.Font.footnote)
                                    .foregroundStyle(Tokens.Palette.inkMuted)
                                TextField("np. Maraton w czerwcu", text: $name)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }
                        durationCard
                        targetsCard
                        reminderCard
                        if let error {
                            Text(error)
                                .font(Tokens.Font.footnote)
                                .foregroundStyle(Tokens.Palette.error)
                        }
                    }
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.vertical, Tokens.Space.lg)
                }
            }
            .navigationTitle(Text("Nowy cel"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Anuluj") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Zapisz") { save() }.disabled(!isValid)
                }
            }
        }
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !selected.isEmpty
    }

    private var durationCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                Text("Czas trwania")
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                ForEach([4, 8, 12], id: \.self) { weeks in
                    Button {
                        useCustomDate = false
                        durationWeeks = weeks
                    } label: {
                        HStack {
                            Image(systemName: durationWeeks == weeks && !useCustomDate
                                ? "circle.inset.filled" : "circle")
                                .foregroundStyle(Tokens.Palette.primary)
                            Text("\(weeks) tygodni")
                                .foregroundStyle(Tokens.Palette.ink)
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }
                Button {
                    useCustomDate = true
                } label: {
                    HStack {
                        Image(systemName: useCustomDate ? "circle.inset.filled" : "circle")
                            .foregroundStyle(Tokens.Palette.primary)
                        Text("Własna data")
                            .foregroundStyle(Tokens.Palette.ink)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                if useCustomDate {
                    DatePicker("", selection: $customEndDate, in: Date()..., displayedComponents: .date)
                        .labelsHidden()
                }
            }
        }
    }

    private var targetsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                Text("Co chcesz osiągnąć?")
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                ForEach(targetOptions) { option in
                    targetRow(
                        type: option.type,
                        label: option.label,
                        suffix: option.suffix,
                        defaultValue: option.defaultValue
                    )
                }
                if selected.contains(.custom) {
                    TextField("Nazwa własnego celu", text: $customName)
                        .textFieldStyle(.roundedBorder)
                }
            }
        }
    }

    private struct TargetOption: Identifiable {
        var type: CustomGoalTarget.TargetType
        var label: String
        var suffix: String
        var defaultValue: Double
        var id: CustomGoalTarget.TargetType { type }
    }

    private var targetOptions: [TargetOption] {
        [
            TargetOption(type: .weightLoss, label: "Schudnąć", suffix: "kg", defaultValue: 5),
            TargetOption(type: .weightGain, label: "Nabrać", suffix: "kg", defaultValue: 3),
            TargetOption(type: .proteinDaily, label: "Białko dziennie", suffix: "g", defaultValue: 130),
            TargetOption(type: .waterDaily, label: "Woda dziennie", suffix: "ml", defaultValue: 2500),
            TargetOption(type: .noFastFoodDays, label: "Bez fast-food", suffix: "dni", defaultValue: 30),
            TargetOption(type: .maxCaloriesDaily, label: "Max kcal dziennie", suffix: "kcal", defaultValue: 1800),
            TargetOption(type: .custom, label: "Własny cel", suffix: "", defaultValue: 1),
        ]
    }

    private func targetRow(
        type: CustomGoalTarget.TargetType,
        label: String,
        suffix: String,
        defaultValue: Double
    ) -> some View {
        let isOn = selected.contains(type)
        let valueBinding = Binding<Double>(
            get: { values[type] ?? defaultValue },
            set: { values[type] = $0 }
        )
        return VStack(alignment: .leading, spacing: 4) {
            Toggle(label, isOn: Binding(
                get: { isOn },
                set: { isSelected in
                    if isSelected {
                        selected.insert(type)
                        if values[type] == nil { values[type] = defaultValue }
                    } else {
                        selected.remove(type)
                    }
                }
            ))
            .tint(Tokens.Palette.primary)
            if isOn {
                HStack {
                    Stepper(value: valueBinding, in: 1...5000, step: type == .waterDaily || type == .maxCaloriesDaily ? 50 : 1) {
                        Text("\(String(format: "%.0f", valueBinding.wrappedValue)) \(suffix)")
                    }
                }
            }
        }
    }

    private var reminderCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                Text("Przypomnienia")
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                let options: [CustomGoalReminder?] = CustomGoalReminder.allCases.map { Optional($0) } + [nil]
                ForEach(options, id: \.self) { option in
                    Button {
                        reminder = option
                    } label: {
                        HStack {
                            Image(systemName: reminder == option ? "circle.inset.filled" : "circle")
                                .foregroundStyle(Tokens.Palette.primary)
                            Text(reminderLabel(option))
                                .foregroundStyle(Tokens.Palette.ink)
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func reminderLabel(_ option: CustomGoalReminder?) -> String {
        switch option {
        case .daily: return "Codzienne motywacyjne"
        case .weekly: return "Tygodniowe podsumowanie"
        case .onDeviation: return "Tylko gdy odchodzę od celu"
        case nil: return "Bez przypomnień"
        }
    }

    private func save() {
        let targets: [CustomGoalTarget] = selected.map { type in
            CustomGoalTarget(
                type: type,
                value: values[type] ?? 0,
                customName: type == .custom ? customName : nil
            )
        }
        let goal = CustomGoal(
            userRemoteID: userRemoteID,
            name: name.trimmingCharacters(in: .whitespaces),
            startDate: Date(),
            endDate: endDate,
            targets: targets,
            reminderType: reminder,
            status: .active
        )
        do {
            try goalsService.create(goal)
            Haptics.success()
            dismiss()
            onSaved()
        } catch GoalsServiceError.tooManyActiveGoals(let max) {
            error = "Możesz mieć maks. \(max) aktywne cele jednocześnie."
        } catch {
            self.error = "Nie udało się zapisać celu."
        }
    }
}
