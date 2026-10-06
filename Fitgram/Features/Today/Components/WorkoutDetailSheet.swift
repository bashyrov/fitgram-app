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
            ZStack {
                ScreenBackground(mood: .calm)
                ScrollView {
                    VStack(spacing: Tokens.Space.lg) {
                        hero
                        goalImpactCard
                        detailsGrid
                        sourceNote
                        deleteButton
                    }
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.vertical, Tokens.Space.lg)
                }
            }
            .navigationTitle(Text(L("Activity details")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Tokens.Palette.ink)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(Tokens.Palette.surfaceMuted.opacity(0.82)))
                    }
                    .accessibilityLabel(Text(L("Close")))
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
    private var hero: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.lg) {
            HStack(alignment: .top, spacing: Tokens.Space.md) {
                ZStack {
                    Circle()
                        .fill(
                            palette.primary
                        )
                        .frame(width: 68, height: 68)
                    Image(systemName: activityIcon)
                        .font(Tokens.Font.archivo(size: 28, weight: 800, width: 115))
                        .foregroundStyle(Tokens.Palette.onPrimary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(workout.activityName)
                        .font(Tokens.Font.archivo(size: 28, weight: 800, width: 115))
                        .foregroundStyle(Tokens.Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(sourceLabel)
                        .font(Tokens.Font.footnote.weight(.semibold))
                        .foregroundStyle(Tokens.Palette.inkMuted)
                }
                Spacer(minLength: 0)
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("+\(Int(workout.caloriesBurnedKcal.rounded()))")
                    .font(Tokens.Font.archivo(size: 44, weight: 800, width: 115))
                    .foregroundStyle(palette.accent)
                    .contentTransition(.numericText())
                Text("kcal")
                    .font(Tokens.Font.bodyEmphasized)
                    .foregroundStyle(Tokens.Palette.inkMuted)
            }
        }
        .padding(Tokens.Space.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frostedGlass(cornerRadius: 30, fillOpacity: 0.88, borderOpacity: 0.05, glowOpacity: 0.08)
    }

    private var detailsGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: Tokens.Space.sm),
                GridItem(.flexible(), spacing: Tokens.Space.sm),
            ],
            spacing: Tokens.Space.sm
        ) {
            detailTile(symbol: "timer", title: L("Duration"), value: durationText, tint: palette.primary)
            if workout.met > 0 {
                detailTile(
                    symbol: "speedometer", title: "MET", value: String(format: "%.1f", workout.met),
                    tint: palette.accent)
            }
            detailTile(symbol: "clock", title: L("Time"), value: timeText, tint: Tokens.Palette.warning)
            detailTile(symbol: "calendar", title: L("Date"), value: dateText, tint: Tokens.Palette.success)
            if let distanceText {
                detailTile(
                    symbol: "point.topleft.down.curvedto.point.bottomright.up",
                    title: distanceTitle,
                    value: distanceText,
                    tint: palette.accent
                )
            }
            if let paceText {
                detailTile(symbol: "figure.run", title: paceTitle, value: paceText, tint: Tokens.Palette.primary)
            }
            if workout.steps > 0 {
                detailTile(
                    symbol: "shoeprints.fill", title: stepsTitle, value: "\(workout.steps)",
                    tint: Tokens.Palette.success)
            }
            if workout.flightsClimbed > 0 {
                detailTile(
                    symbol: "stairs", title: flightsTitle, value: "\(workout.flightsClimbed)",
                    tint: Tokens.Palette.warning)
            }
            if let averageHeartRateText {
                detailTile(
                    symbol: "heart.fill", title: averageHeartRateTitle, value: averageHeartRateText,
                    tint: Tokens.Palette.error)
            }
            if let heartRateRangeText {
                detailTile(
                    symbol: "waveform.path.ecg", title: heartRateRangeTitle, value: heartRateRangeText,
                    tint: Tokens.Palette.error)
            }
        }
    }

    private var goalImpactCard: some View {
        HStack(alignment: .center, spacing: Tokens.Space.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text(goalImpactTitle)
                    .font(Tokens.Font.bodyEmphasized)
                    .foregroundStyle(Tokens.Palette.ink)
                Text(countsTowardDailyGoal ? goalImpactEnabledSubtitle : goalImpactDisabledSubtitle)
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: Tokens.Space.md)
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
            .tint(palette.accent)
        }
        .padding(Tokens.Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frostedGlass(cornerRadius: 22, fillOpacity: 0.78, borderOpacity: 0.04, glowOpacity: 0.03)
    }

    private func detailTile(symbol: String, title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(Circle().fill(tint.opacity(0.14)))
            Text(value)
                .font(Tokens.Font.manrope(18, weight: 800))
                .foregroundStyle(Tokens.Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(Tokens.Font.caption.weight(.semibold))
                .foregroundStyle(Tokens.Palette.inkMuted)
        }
        .padding(Tokens.Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frostedGlass(cornerRadius: 22, fillOpacity: 0.78, borderOpacity: 0.04, glowOpacity: 0.03)
    }

    private var sourceNote: some View {
        HStack(alignment: .top, spacing: Tokens.Space.sm) {
            Image(systemName: workout.source == .appleHealth ? "heart.fill" : "pencil.and.list.clipboard")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(palette.accent)
            Text(sourceDescription)
                .font(Tokens.Font.footnote)
                .foregroundStyle(Tokens.Palette.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Tokens.Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(palette.accentSoft.opacity(0.42))
        )
    }

    private var deleteButton: some View {
        Button {
            isDeleteConfirmationPresented = true
        } label: {
            HStack {
                Image(systemName: "trash.fill")
                Text(deleteTitle)
            }
            .font(Tokens.Font.bodyEmphasized)
            .foregroundStyle(Tokens.Palette.error)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Tokens.Palette.error.opacity(0.10))
            )
        }
        .buttonStyle(.pressable)
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
