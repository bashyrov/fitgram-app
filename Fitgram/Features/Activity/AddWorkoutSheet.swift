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
            ZStack {
                ScreenBackground(mood: .social)
                ScrollView {
                    LazyVStack(spacing: Tokens.Space.lg) {
                        hero
                        searchCard
                        durationCard
                        manualCaloriesCard
                        goalImpactCard
                        noteCard
                    }
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.top, Tokens.Space.md)
                    .padding(.bottom, 120)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(Text(title))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(closeTitle, action: onDismiss)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(doneTitle) { focusedField = nil }
                        .font(Tokens.Font.bodyEmphasized)
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

    private var hero: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            HStack(spacing: Tokens.Space.md) {
                Image(systemName: selected.symbol)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Tokens.Palette.onPrimary)
                    .frame(width: 58, height: 58)
                    .background(
                        Circle().fill(
                            LinearGradient(
                                colors: [Tokens.Palette.primary, Tokens.Palette.accent],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    )
                VStack(alignment: .leading, spacing: 3) {
                    Text(selected.localizedName)
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .foregroundStyle(Tokens.Palette.ink)
                    Text(String.localizedStringWithFormat(heroSubtitleFormat, selected.met, currentWeightKg))
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                }
            }
            HStack(spacing: Tokens.Space.sm) {
                statPill(String.localizedStringWithFormat("%lld min", durationMinutes), tint: Tokens.Palette.primary)
                statPill(
                    String.localizedStringWithFormat("%lld kcal", Int(estimatedCalories.rounded())),
                    tint: Tokens.Palette.accent)
                statPill(manualCalories == nil ? "MET" : manualTitle, tint: Tokens.Palette.warning)
            }
        }
        .padding(Tokens.Space.lg)
        .frostedGlass(cornerRadius: 28, fillOpacity: 0.80, borderOpacity: 0.06, glowOpacity: 0.05)
    }

    private var searchCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                Text(activityTitle)
                    .font(Tokens.Font.headline)
                    .foregroundStyle(Tokens.Palette.ink)
                TextField(searchPlaceholder, text: $query)
                    .textInputAutocapitalization(.never)
                    .focused($focusedField, equals: .search)
                    .padding(Tokens.Space.md)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Tokens.Palette.surfaceMuted)
                    )
                LazyVStack(spacing: Tokens.Space.xs) {
                    ForEach(filteredItems.prefix(8)) { item in
                        Button {
                            selected = item
                            Haptics.selection()
                        } label: {
                            workoutRow(item)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var durationCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                HStack {
                    Text(durationTitle)
                        .font(Tokens.Font.headline)
                        .foregroundStyle(Tokens.Palette.ink)
                    Spacer()
                    Text(String.localizedStringWithFormat("%lld min", durationMinutes))
                        .font(Tokens.Font.bodyEmphasized)
                        .foregroundStyle(Tokens.Palette.primary)
                }
                Slider(
                    value: Binding(get: { Double(durationMinutes) }, set: { durationMinutes = Int($0.rounded()) }),
                    in: 5...240, step: 5)
            }
        }
    }

    private var manualCaloriesCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                Text(manualCaloriesTitle)
                    .font(Tokens.Font.headline)
                    .foregroundStyle(Tokens.Palette.ink)
                Text(manualCaloriesHint)
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                TextField(
                    String.localizedStringWithFormat(
                        "%lld kcal",
                        Int(
                            WorkoutCatalog.calories(
                                met: selected.met, weightKg: currentWeightKg, durationMinutes: durationMinutes
                            ).rounded())), text: $manualCaloriesText
                )
                .keyboardType(.decimalPad)
                .focused($focusedField, equals: .calories)
                .padding(Tokens.Space.md)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Tokens.Palette.surfaceMuted)
                )
            }
        }
    }

    private var noteCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                Text(noteTitle)
                    .font(Tokens.Font.headline)
                    .foregroundStyle(Tokens.Palette.ink)
                TextField(notePlaceholder, text: $note, axis: .vertical)
                    .focused($focusedField, equals: .note)
                    .lineLimit(2...4)
                    .padding(Tokens.Space.md)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Tokens.Palette.surfaceMuted)
                    )
            }
        }
    }

    private var goalImpactCard: some View {
        Card {
            HStack(alignment: .center, spacing: Tokens.Space.md) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(goalImpactTitle)
                        .font(Tokens.Font.headline)
                        .foregroundStyle(Tokens.Palette.ink)
                    Text(goalImpactSubtitle)
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: Tokens.Space.md)
                Toggle("", isOn: $countsTowardDailyGoal)
                    .labelsHidden()
                    .tint(Tokens.Palette.primary)
            }
        }
    }

    private var bottomBar: some View {
        VStack(spacing: Tokens.Space.sm) {
            Button {
                save()
            } label: {
                HStack(spacing: Tokens.Space.sm) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 17, weight: .semibold))
                    Text(String.localizedStringWithFormat(saveFormat, Int(estimatedCalories.rounded())))
                        .font(Tokens.Font.bodyEmphasized)
                }
                .foregroundStyle(Tokens.Palette.onPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: Tokens.Radius.pill, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Tokens.Palette.primary, Tokens.Palette.accent],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
            }
            .buttonStyle(PressableButtonStyle())
        }
        .padding(.horizontal, Tokens.Space.screenPadding)
        .padding(.top, Tokens.Space.md)
        .padding(.bottom, Tokens.Space.sm)
        .background {
            LinearGradient(
                colors: [
                    Tokens.Palette.background.opacity(0),
                    Tokens.Palette.background.opacity(0.86),
                    Tokens.Palette.background,
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    private func workoutRow(_ item: WorkoutCatalogItem) -> some View {
        HStack(spacing: Tokens.Space.sm) {
            Image(systemName: item.symbol)
                .foregroundStyle(item.id == selected.id ? Tokens.Palette.onPrimary : Tokens.Palette.primary)
                .frame(width: 32, height: 32)
                .background(Circle().fill(item.id == selected.id ? Tokens.Palette.primary : Tokens.Palette.primarySoft))
            VStack(alignment: .leading, spacing: 2) {
                Text(item.localizedName)
                    .font(Tokens.Font.bodyEmphasized)
                    .foregroundStyle(Tokens.Palette.ink)
                Text(String.localizedStringWithFormat("MET %.1f", item.met))
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Palette.inkMuted)
            }
            Spacer()
            if item.id == selected.id {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Tokens.Palette.primary)
            }
        }
        .padding(.vertical, 7)
    }

    private func statPill(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(Tokens.Font.caption.weight(.bold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Capsule().fill(tint.opacity(0.12)))
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
