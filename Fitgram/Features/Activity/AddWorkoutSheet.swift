import SwiftUI

struct AddWorkoutSheet: View {
    let userRemoteID: String
    let currentWeightKg: Double
    let workoutService: WorkoutService
    let onDismiss: () -> Void
    let onSaved: (WorkoutEntry) -> Void

    @State private var query = ""
    @State private var selected: WorkoutCatalogItem = WorkoutCatalog.items[0]
    @State private var durationMinutes = 30
    @State private var manualCaloriesText = ""
    @State private var note = ""
    @State private var countsTowardDailyGoal = true
    @State private var saveError: String?
    @FocusState private var focusedField: Field?

    private enum Field {
        case search
        case calories
        case note
    }

    private var filteredItems: [WorkoutCatalogItem] {
        WorkoutCatalog.search(query)
    }

    private var manualCalories: Double? {
        let normalized = manualCaloriesText.replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized), value > 0 else { return nil }
        return value
    }

    private var estimatedCalories: Double {
        manualCalories
            ?? WorkoutCatalog.calories(
                met: selected.met,
                weightKg: currentWeightKg,
                durationMinutes: durationMinutes
            )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    MonoH1(text: title, sub: subtitle)
                        .padding(.bottom, 4)
                    searchCard
                    durationCard
                    manualCaloriesCard
                    goalImpactCard
                    noteCard
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Tokens.Palette.background.ignoresSafeArea())
            .monoNavigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    MonoNavText(title: closeTitle, action: onDismiss)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    MonoNavPill(title: doneTitle) { save() }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(doneTitle) { focusedField = nil }
                        .font(Tokens.Font.manrope(15, weight: 800))
                }
            }
            .safeAreaInset(edge: .bottom) {
                bottomBar
            }
            .alert(errorTitle, isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
                Button("OK", role: .cancel) { saveError = nil }
            } message: {
                Text(saveError ?? "")
            }
        }
    }

    private var searchCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            MonoLabel(text: activityTitle)
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Tokens.Mono.muted)
                TextField(searchPlaceholder, text: $query)
                    .font(Tokens.Font.manrope(14, weight: 600))
                    .foregroundStyle(Tokens.Palette.ink)
                    .textInputAutocapitalization(.never)
                    .focused($focusedField, equals: .search)
            }
            .padding(.horizontal, 12)
            .frame(height: 46)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Tokens.Mono.line2, lineWidth: 1)
            )
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3),
                spacing: 8
            ) {
                ForEach(filteredItems.prefix(9)) { item in
                    Button {
                        selected = item
                        Haptics.selection()
                    } label: {
                        sportTile(item)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(item.id == selected.id ? .isSelected : [])
                }
            }
        }
        .monoCard(padding: 16)
    }

    private var durationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                MonoLabel(text: durationTitle)
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(durationMinutes)")
                        .font(Tokens.Font.monoNumber(24))
                        .foregroundStyle(Tokens.Palette.ink)
                        .contentTransition(.numericText())
                    Text("min")
                        .font(Tokens.Font.manrope(12, weight: 700))
                        .foregroundStyle(Tokens.Mono.muted)
                }
            }
            VStack(spacing: 6) {
                Slider(
                    value: Binding(get: { Double(durationMinutes) }, set: { durationMinutes = Int($0.rounded()) }),
                    in: 5...240, step: 5
                )
                .tint(Tokens.Mono.strong)
                HStack {
                    Text("5 min")
                    Spacer()
                    Text("240 min")
                }
                .font(Tokens.Font.manrope(11, weight: 700))
                .foregroundStyle(Tokens.Mono.muted)
            }
            Text(String.localizedStringWithFormat(heroSubtitleFormat, selected.met, currentWeightKg))
                .font(Tokens.Font.manrope(12, weight: 600))
                .foregroundStyle(Tokens.Mono.muted)
        }
        .monoCard(padding: 16)
    }

    private var manualCaloriesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                MonoLabel(text: manualCaloriesTitle)
                Spacer(minLength: 8)
                manualCaloriesStepper
            }
            Text(manualCaloriesHint)
                .font(Tokens.Font.manrope(12, weight: 600))
                .foregroundStyle(Tokens.Mono.muted)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .monoCard(padding: 16)
    }

    private var metCalories: Int {
        Int(
            WorkoutCatalog.calories(
                met: selected.met, weightKg: currentWeightKg, durationMinutes: durationMinutes
            ).rounded())
    }

    private var manualCaloriesStepper: some View {
        HStack(spacing: 10) {
            stepperButton("minus") {
                guard let current = manualCalories else { return }
                let next = Int(current.rounded()) - 10
                manualCaloriesText = next > 0 ? "\(next)" : ""
            }
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                TextField("—", text: $manualCaloriesText, prompt: Text("—"))
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .calories)
                    .multilineTextAlignment(.center)
                    .font(Tokens.Font.monoNumber(20))
                    .foregroundStyle(Tokens.Palette.ink)
                    .frame(width: 52)
                Text("kcal")
                    .font(Tokens.Font.manrope(12, weight: 700))
                    .foregroundStyle(Tokens.Mono.muted)
            }
            stepperButton("plus") {
                let base = manualCalories.map { Int($0.rounded()) } ?? metCalories
                manualCaloriesText = "\(base + 10)"
            }
        }
    }

    private func stepperButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
            Haptics.light()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(Tokens.Palette.ink)
                .frame(width: 40, height: 40)
                .overlay(Circle().stroke(Tokens.Mono.line2, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var noteCard: some View {
        MonoField(label: noteTitle, multiline: true) {
            TextField(notePlaceholder, text: $note, axis: .vertical)
                .focused($focusedField, equals: .note)
                .lineLimit(2...4)
        }
        .monoCard(padding: 16)
    }

    private var goalImpactCard: some View {
        VStack(spacing: 0) {
            MonoRow(title: goalImpactTitle, sub: goalImpactSubtitle) {
                Toggle("", isOn: $countsTowardDailyGoal)
                    .labelsHidden()
                    .toggleStyle(MonoToggleStyle())
            }
        }
        .monoRowsCard()
    }

    private var bottomBar: some View {
        MonoBottomBar {
            MonoButton(
                title: String.localizedStringWithFormat(saveFormat, Int(estimatedCalories.rounded())),
                kind: .dark,
                icon: "checkmark"
            ) {
                save()
            }
        }
    }

    private func sportTile(_ item: WorkoutCatalogItem) -> some View {
        let isOn = item.id == selected.id
        return VStack(spacing: 6) {
            Image(systemName: item.symbol)
                .font(.system(size: 19, weight: .semibold))
            Text(item.localizedName)
                .font(Tokens.Font.manrope(12, weight: 800))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 4)
        }
        .foregroundStyle(isOn ? Tokens.Mono.hi : Tokens.Palette.ink)
        .frame(maxWidth: .infinity)
        .frame(height: 74)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isOn ? Tokens.Mono.hero : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isOn ? Color.clear : Tokens.Mono.line2, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func save() {
        do {
            let entry = try workoutService.log(
                item: selected,
                durationMinutes: durationMinutes,
                weightKg: currentWeightKg,
                manualCalories: manualCalories,
                userRemoteID: userRemoteID,
                countsTowardDailyGoal: countsTowardDailyGoal,
                note: note
            )
            Haptics.success()
            onSaved(entry)
        } catch {
            Haptics.warning()
            saveError = String(describing: error)
        }
    }
}

extension AddWorkoutSheet {
    fileprivate var title: String {
        TL(
            pl: "Dodaj trening", en: "Add workout", uk: "Додати тренування", ru: "Добавить тренировку",
            es: "Añadir entrenamiento")
    }
    fileprivate var subtitle: String {
        TL(
            pl: "Trening ma własny budżet kcal i nie miesza się z posiłkami.",
            en: "Workouts have their own kcal budget and don't mix with meals.",
            uk: "Тренування має власний бюджет ккал і не змішується з їжею.",
            ru: "У тренировки свой бюджет ккал, он не смешивается с едой.",
            es: "El entreno tiene su propio presupuesto de kcal y no se mezcla con las comidas.")
    }
    fileprivate var closeTitle: String { TL(pl: "Zamknij", en: "Close", uk: "Закрити", ru: "Закрыть", es: "Cerrar") }
    fileprivate var doneTitle: String { TL(pl: "Gotowe", en: "Done", uk: "Готово", ru: "Готово", es: "Listo") }
    fileprivate var activityTitle: String {
        TL(pl: "Aktywność", en: "Activity", uk: "Активність", ru: "Активность", es: "Actividad")
    }
    fileprivate var searchPlaceholder: String {
        TL(
            pl: "Szukaj sportu", en: "Search activity", uk: "Пошук активності", ru: "Поиск активности",
            es: "Buscar actividad")
    }
    fileprivate var durationTitle: String {
        TL(pl: "Czas trwania", en: "Duration", uk: "Тривалість", ru: "Длительность", es: "Duración")
    }
    fileprivate var manualCaloriesTitle: String {
        TL(
            pl: "Kalorie ręcznie", en: "Manual calories", uk: "Калорії вручну", ru: "Калории вручную",
            es: "Calorías manuales")
    }
    fileprivate var manualCaloriesHint: String {
        TL(
            pl: "Opcjonalnie. Jeśli wpiszesz kcal z bieżni lub zegarka, użyjemy tej wartości zamiast MET.",
            en: "Optional. If you enter treadmill/watch kcal, we use it instead of MET.",
            uk: "Необов'язково. Якщо введеш ккал з тренажера чи годинника, використаємо їх замість MET.",
            ru: "Необязательно. Если введёшь ккал с тренажёра или часов, используем их вместо MET.",
            es: "Opcional. Si introduces kcal de cinta/reloj, usamos ese valor en vez de MET.")
    }
    fileprivate var goalImpactTitle: String {
        TL(
            pl: "Dodaj kcal do dziennego celu",
            en: "Add kcal to the daily target",
            uk: "Додати ккал до денної цілі",
            ru: "Добавить ккал к дневной норме",
            es: "Sumar kcal al objetivo diario")
    }
    fileprivate var goalImpactSubtitle: String {
        TL(
            pl: "Wyłącz, jeśli chcesz tylko zapisać trening bez zwiększania budżetu.",
            en: "Turn this off to log the workout without increasing the budget.",
            uk: "Вимкни, якщо хочеш записати тренування без збільшення бюджету.",
            ru: "Выключи, если хочешь записать тренировку без увеличения бюджета.",
            es: "Desactívalo para registrar el entreno sin aumentar el presupuesto.")
    }
    fileprivate var noteTitle: String { TL(pl: "Notatka", en: "Note", uk: "Нотатка", ru: "Заметка", es: "Nota") }
    fileprivate var notePlaceholder: String {
        TL(
            pl: "Np. po pracy, siłownia", en: "E.g. after work, gym", uk: "Напр. після роботи, зал",
            ru: "Напр. после работы, зал", es: "Ej. después del trabajo, gym")
    }
    fileprivate var manualTitle: String { TL(pl: "Ręcznie", en: "Manual", uk: "Вручну", ru: "Вручную", es: "Manual") }
    fileprivate var heroSubtitleFormat: String {
        TL(
            pl: "MET %.1f · waga %.1f kg", en: "MET %.1f · weight %.1f kg", uk: "MET %.1f · вага %.1f кг",
            ru: "MET %.1f · вес %.1f кг", es: "MET %.1f · peso %.1f kg")
    }
    fileprivate var saveFormat: String {
        TL(
            pl: "Zapisz +%lld kcal", en: "Save +%lld kcal", uk: "Зберегти +%lld ккал", ru: "Сохранить +%lld ккал",
            es: "Guardar +%lld kcal")
    }
    fileprivate var errorTitle: String {
        TL(
            pl: "Nie udało się zapisać", en: "Couldn't save", uk: "Не вдалося зберегти", ru: "Не удалось сохранить",
            es: "No se pudo guardar")
    }
}
