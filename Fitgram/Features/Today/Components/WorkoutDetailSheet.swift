import SwiftUI

struct WorkoutDetailSheet: View {
    let workout: WorkoutEntry
    let onToggleCountsTowardGoal: (Bool) -> Void
    let onDelete: () -> Void
    let onDismiss: () -> Void

    @State private var isDeleteConfirmationPresented = false
    @State private var countsTowardDailyGoal: Bool
    @AppStorage(AppAccentPalette.storageKey) private var accentRaw = AppAccentPalette.rose.rawValue

    init(
        workout: WorkoutEntry,
        onToggleCountsTowardGoal: @escaping (Bool) -> Void,
        onDelete: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.workout = workout
        self.onToggleCountsTowardGoal = onToggleCountsTowardGoal
        self.onDelete = onDelete
        self.onDismiss = onDismiss
        self._countsTowardDailyGoal = State(initialValue: workout.countsTowardDailyGoal)
    }

    private var palette: AppAccentPalette {
        AppAccentPalette(rawValue: accentRaw) ?? .rose
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    hero
                    detailsGrid
                    goalImpactCard
                    sourceNote
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.top, 12)
                .padding(.bottom, Tokens.Space.lg)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(Tokens.Palette.background.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                MonoBottomBar {
                    MonoButton(title: deleteTitle, kind: .danger, icon: "trash") {
                        isDeleteConfirmationPresented = true
                    }
                }
            }
            .monoNavigationTitle(L("Activity details"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    MonoNavText(title: L("Close"), action: onDismiss)
                }
            }
        }
        .confirmationDialog(
            deleteTitle,
            isPresented: $isDeleteConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button(deleteTitle, role: .destructive) {
                Haptics.warning()
                onDelete()
            }
            Button(L("Cancel"), role: .cancel) {}
        } message: {
            Text(deleteMessage)
        }
    }
}

// MARK: - Sections
extension WorkoutDetailSheet {
    // Mockup hero: hi icon box + "RUCH · 07:30" / name, +kcal 64 pt, source badge.
    private var hero: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                MonoIconBox(systemName: activityIcon, style: .hi, size: 44)
                VStack(alignment: .leading, spacing: 0) {
                    MonoLabel(text: heroKicker, onHero: true)
                    Text(workout.activityName)
                        .font(Tokens.Font.manrope(20, weight: 800))
                        .foregroundStyle(Tokens.Mono.onHero)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(verbatim: "+\(Int(workout.caloriesBurnedKcal.rounded()))")
                    .font(Tokens.Font.monoNumber(64))
                    .foregroundStyle(Tokens.Mono.onHero)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .contentTransition(.numericText())
                Text(verbatim: "kcal")
                    .font(Tokens.Font.manrope(16, weight: 800))
                    .foregroundStyle(Tokens.Mono.heroMuted)
            }

            HStack(spacing: 6) {
                Image(systemName: workout.source == .appleHealth ? "heart.fill" : "pencil")
                    .font(.system(size: 11, weight: .bold))
                Text(sourceLabel)
                    .font(Tokens.Font.manrope(12, weight: 700))
                    .lineLimit(1)
            }
            .foregroundStyle(Tokens.Mono.onHero)
            .padding(.horizontal, 10)
            .frame(height: 26)
            .background(Capsule().fill(Tokens.Mono.heroLine))
        }
        .monoHero(padding: 20)
    }

    private var detailsGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8),
            ],
            spacing: 8
        ) {
            detailTile(title: L("Duration"), value: durationText)
            if workout.met > 0 {
                detailTile(title: "MET", value: String(format: "%.1f", workout.met))
            }
            detailTile(title: L("Time"), value: timeText)
            detailTile(title: L("Date"), value: dateText)
            if let distanceText {
                detailTile(title: distanceTitle, value: distanceText)
            }
            if let paceText {
                detailTile(title: paceTitle, value: paceText)
            }
            if workout.steps > 0 {
                detailTile(title: stepsTitle, value: "\(workout.steps)")
            }
            if workout.flightsClimbed > 0 {
                detailTile(title: flightsTitle, value: "\(workout.flightsClimbed)")
            }
            if let averageHeartRateText {
                detailTile(title: averageHeartRateTitle, value: averageHeartRateText)
            }
            if let heartRateRangeText {
                detailTile(title: heartRateRangeTitle, value: heartRateRangeText)
            }
        }
    }

    // Mockup: rows card with a single toggle row (no icon).
    private var goalImpactCard: some View {
        MonoRow(
            title: goalImpactTitle,
            sub: countsTowardDailyGoal ? goalImpactEnabledSubtitle : goalImpactDisabledSubtitle
        ) {
            Toggle(
                "",
                isOn: Binding(
                    get: { countsTowardDailyGoal },
                    set: { newValue in
                        countsTowardDailyGoal = newValue
                        onToggleCountsTowardGoal(newValue)
                        Haptics.light()
                    }
                )
            )
            .labelsHidden()
            .toggleStyle(MonoToggleStyle())
            .fixedSize()
        }
        .monoRowsCard()
    }

    // Mockup tile: upper-case label above a 20 pt italic number.
    private func detailTile(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            MonoLabel(text: title)
            Text(value)
                .font(Tokens.Font.monoNumber(20))
                .foregroundStyle(Tokens.Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .monoTile()
        .accessibilityElement(children: .combine)
    }

    // Mockup: muted paragraph under the toggle card (18 pt text inset).
    private var sourceNote: some View {
        MonoHint(text: sourceDescription)
    }
}

// MARK: - Copy
extension WorkoutDetailSheet {
    private var activityIcon: String {
        if workout.activityID.contains("walk") { return "figure.walk.motion" }
        if workout.activityID.contains("run") { return "figure.run" }
        if workout.activityID.contains("bike") || workout.activityID.contains("cycling") { return "bicycle" }
        if workout.activityID.contains("swim") { return "figure.pool.swim" }
        if workout.activityID.contains("strength") || workout.activityID.contains("gym") { return "dumbbell.fill" }
        if workout.activityID.contains("yoga") { return "figure.mind.and.body" }
        return "bolt.heart.fill"
    }

    private var heroKicker: String {
        TL(pl: "Ruch", en: "Movement", uk: "Рух", ru: "Движение", es: "Movimiento") + " · " + timeText
    }

    private var sourceLabel: String {
        workout.source == .appleHealth
            ? (workout.sourceName?.isEmpty == false ? workout.sourceName ?? "Apple Health" : "Apple Health")
            : TL(
                pl: "Dodane ręcznie", en: "Added manually", uk: "Додано вручну", ru: "Добавлено вручную",
                es: "Añadido manualmente"
            )
    }

    private var sourceDescription: String {
        if !countsTowardDailyGoal {
            return TL(
                pl: "Trening jest zapisany w dzienniku, ale jego kcal nie zwiększają celu tego dnia.",
                en: "The workout stays in the diary, but its kcal do not increase this day's target.",
                uk: "Тренування збережене в щоденнику, але його ккал не збільшують ціль цього дня.",
                ru: "Тренировка сохранена в дневнике, но её ккал не увеличивают цель этого дня.",
                es: "El entreno queda en el diario, pero sus kcal no aumentan el objetivo de ese día."
            )
        }
        if workout.source == .appleHealth {
            return TL(
                pl:
                    "Usunięcie tej pozycji usuwa ją tylko z Fitgram. Oryginalny trening w Apple Health zostaje bez zmian.",
                en:
                    "Deleting this entry removes it only from Fitgram. The original Apple Health workout stays unchanged.",
                uk: "Видалення прибере запис лише з Fitgram. Оригінальне тренування в Apple Health не зміниться.",
                ru: "Удаление уберет запись только из Fitgram. Оригинальная тренировка в Apple Health не изменится.",
                es:
                    "Eliminar esta entrada solo la quita de Fitgram. El entrenamiento original de Apple Health no cambia."
            )
        }
        return TL(
            pl: "Ta aktywność zwiększa budżet kalorii wybranego dnia i może zostać usunięta w każdej chwili.",
            en: "This activity increases the calorie budget for the selected day and can be deleted anytime.",
            uk: "Ця активність збільшує бюджет калорій вибраного дня, її можна видалити будь-коли.",
            ru: "Эта активность увеличивает бюджет калорий выбранного дня, ее можно удалить в любой момент.",
            es: "Esta actividad aumenta el presupuesto de calorías del día elegido y se puede eliminar cuando quieras."
        )
    }

    private var durationText: String {
        String.localizedStringWithFormat(
            TL(pl: "%lld min", en: "%lld min", uk: "%lld хв", ru: "%lld мин", es: "%lld min"),
            workout.durationMinutes
        )
    }

    private var rowSubtitle: String {
        var parts = [durationText]
        if let distanceText {
            parts.append(distanceText)
        } else if workout.met > 0 {
            parts.append(String(format: "MET %.1f", workout.met))
        }
        if let averageHeartRateText {
            parts.append(averageHeartRateText)
        }
        return parts.joined(separator: " · ")
    }

    private var distanceText: String? {
        guard let meters = workout.distanceMeters, meters >= 1 else { return nil }
        if meters >= 1000 {
            return String.localizedStringWithFormat("%.2f km", meters / 1000)
        }
        return String.localizedStringWithFormat(
            TL(pl: "%lld m", en: "%lld m", uk: "%lld м", ru: "%lld м", es: "%lld m"),
            Int(meters.rounded())
        )
    }

    private var paceText: String? {
        guard let meters = workout.distanceMeters, meters >= 100, workout.durationMinutes > 0 else { return nil }
        let minutesPerKm = Double(workout.durationMinutes) / max(0.1, meters / 1000)
        guard minutesPerKm.isFinite, minutesPerKm < 60 else { return nil }
        let minutes = Int(minutesPerKm)
        let seconds = Int(((minutesPerKm - Double(minutes)) * 60).rounded())
        return String(format: "%d:%02d /km", minutes, min(59, seconds))
    }

    private var averageHeartRateText: String? {
        guard let value = workout.averageHeartRateBpm, value > 0 else { return nil }
        return String.localizedStringWithFormat(
            TL(pl: "%lld bpm", en: "%lld bpm", uk: "%lld уд/хв", ru: "%lld уд/мин", es: "%lld ppm"),
            Int(value.rounded())
        )
    }

    private var heartRateRangeText: String? {
        guard let min = workout.minHeartRateBpm, let max = workout.maxHeartRateBpm, min > 0, max > 0 else { return nil }
        return "\(Int(min.rounded()))–\(Int(max.rounded()))"
    }

    private var distanceTitle: String {
        TL(pl: "Dystans", en: "Distance", uk: "Дистанція", ru: "Дистанция", es: "Distancia")
    }

    private var paceTitle: String {
        TL(pl: "Tempo", en: "Pace", uk: "Темп", ru: "Темп", es: "Ritmo")
    }

    private var stepsTitle: String {
        TL(pl: "Kroki", en: "Steps", uk: "Кроки", ru: "Шаги", es: "Pasos")
    }

    private var flightsTitle: String {
        TL(pl: "Piętra", en: "Flights", uk: "Поверхи", ru: "Этажи", es: "Pisos")
    }

    private var averageHeartRateTitle: String {
        TL(pl: "Śr. tętno", en: "Avg HR", uk: "Сер. пульс", ru: "Ср. пульс", es: "FC media")
    }

    private var heartRateRangeTitle: String {
        TL(pl: "Zakres tętna", en: "HR range", uk: "Діапазон пульсу", ru: "Диапазон пульса", es: "Rango FC")
    }

    private var goalImpactTitle: String {
        TL(
            pl: "Liczyć kcal w celu dnia",
            en: "Count kcal in daily target",
            uk: "Враховувати ккал у денній цілі",
            ru: "Учитывать ккал в дневной норме",
            es: "Contar kcal en el objetivo diario")
    }

    private var goalImpactEnabledSubtitle: String {
        TL(
            pl: "Ta aktywność zwiększa budżet kcal wybranego dnia.",
            en: "This activity increases the kcal budget for the selected day.",
            uk: "Ця активність збільшує бюджет ккал вибраного дня.",
            ru: "Эта активность увеличивает бюджет ккал выбранного дня.",
            es: "Esta actividad aumenta el presupuesto kcal del día elegido.")
    }

    private var goalImpactDisabledSubtitle: String {
        TL(
            pl: "Zostaje w historii, ale cel kcal nie rośnie.",
            en: "It stays in history, but the kcal target does not increase.",
            uk: "Вона лишається в історії, але ціль ккал не зростає.",
            ru: "Она остаётся в истории, но цель ккал не растёт.",
            es: "Queda en el historial, pero el objetivo kcal no sube.")
    }

    private var timeText: String {
        workout.recordedAt.formatted(
            .dateTime.hour().minute().locale(Locale(identifier: LocalizationStore.currentLanguageCode()))
        )
    }

    private var dateText: String {
        workout.recordedAt.formatted(
            .dateTime.day().month(.abbreviated).locale(Locale(identifier: LocalizationStore.currentLanguageCode()))
        )
    }

    private var deleteTitle: String {
        TL(
            pl: "Usuń aktywność", en: "Delete activity", uk: "Видалити активність", ru: "Удалить активность",
            es: "Eliminar actividad")
    }

    private var deleteMessage: String {
        workout.source == .appleHealth
            ? TL(
                pl: "Dane w Apple Health zostaną bez zmian.",
                en: "Apple Health data stays unchanged.",
                uk: "Дані Apple Health не зміняться.",
                ru: "Данные Apple Health не изменятся.",
                es: "Apple Health no cambiará."
            )
            : TL(
                pl: "Trening zniknie z budżetu kalorii tego dnia.",
                en: "The workout will be removed from this day's calorie budget.",
                uk: "Тренування зникне з бюджету калорій цього дня.",
                ru: "Тренировка исчезнет из бюджета калорий этого дня.",
                es: "El entrenamiento se quitará del presupuesto de ese día."
            )
    }
}
