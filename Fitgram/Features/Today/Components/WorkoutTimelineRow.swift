import SwiftUI

struct WorkoutTimelineRow: View {
    let workout: WorkoutEntry
    let onOpen: () -> Void
    let onDelete: () -> Void
    @State private var isDeleteConfirmationPresented = false
    @AppStorage(AppAccentPalette.storageKey) private var accentRaw = AppAccentPalette.rose.rawValue

    private var palette: AppAccentPalette {
        AppAccentPalette(rawValue: accentRaw) ?? .rose
    }

    private static var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: LocalizationStore.currentLanguageCode())
        return formatter
    }

    var body: some View {
        HStack(spacing: Tokens.Space.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        palette.accent.opacity(0.22)
                    )
                    .frame(width: 50, height: 50)
                Image(systemName: activityIcon)
                    .font(Tokens.Font.manrope(20, weight: 800))
                    .foregroundStyle(palette.accent)
            }

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: Tokens.Space.xs) {
                    Text(TL(pl: "Ruch", en: "Move", uk: "Рух", ru: "Движение", es: "Movimiento"))
                        .font(Tokens.Font.caption.weight(.bold))
                        .foregroundStyle(palette.accent)
                        .textCase(.uppercase)
                    Text(Self.timeFormatter.string(from: workout.recordedAt))
                        .font(Tokens.Font.caption.weight(.semibold))
                        .foregroundStyle(Tokens.Palette.inkSubtle)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(workout.activityName)
                        .font(Tokens.Font.bodyEmphasized)
                        .foregroundStyle(Tokens.Palette.ink)
                        .lineLimit(1)
                    Text(
                        rowSubtitle
                    )
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                }
            }
            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 3) {
                Text(
                    String.localizedStringWithFormat(
                        TL(pl: "+%lld", en: "+%lld", uk: "+%lld", ru: "+%lld", es: "+%lld"),
                        Int(workout.caloriesBurnedKcal.rounded()))
                )
                .font(Tokens.Font.title3)
                .foregroundStyle(palette.accent)
                .contentTransition(.numericText())
                Text("kcal")
                    .font(Tokens.Font.caption.weight(.bold))
                    .foregroundStyle(Tokens.Palette.inkSubtle)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Tokens.Palette.inkSubtle)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            Haptics.light()
            onOpen()
        }
        .padding(.horizontal, Tokens.Space.md)
        .padding(.vertical, 14)
        .monoCard(radius: Tokens.Mono.Radius.tile, padding: nil)
        .contextMenu {
            Button(role: .destructive) {
                isDeleteConfirmationPresented = true
            } label: {
                Label(deleteTitle, systemImage: "trash")
            }
        }
        .confirmationDialog(
            deleteTitle,
            isPresented: $isDeleteConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button(deleteTitle, role: .destructive) {
                onDelete()
            }
            Button(cancelTitle, role: .cancel) {}
        } message: {
            Text(deleteMessage)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    private var activityIcon: String {
        if workout.activityID.contains("walk") { return "figure.walk.motion" }
        if workout.activityID.contains("run") { return "figure.run" }
        if workout.activityID.contains("bike") || workout.activityID.contains("cycling") { return "bicycle" }
        if workout.activityID.contains("swim") { return "figure.pool.swim" }
        if workout.activityID.contains("strength") || workout.activityID.contains("gym") { return "dumbbell.fill" }
        if workout.activityID.contains("yoga") { return "figure.mind.and.body" }
        return "bolt.heart.fill"
    }

    private var rowSubtitle: String {
        var parts = [
            String.localizedStringWithFormat(
                TL(pl: "%lld min", en: "%lld min", uk: "%lld хв", ru: "%lld мин", es: "%lld min"),
                workout.durationMinutes
            )
        ]
        if let meters = workout.distanceMeters, meters >= 1 {
            parts.append(meters >= 1000 ? String(format: "%.2f km", meters / 1000) : "\(Int(meters.rounded())) m")
        } else if workout.met > 0 {
            parts.append(String(format: "MET %.1f", workout.met))
        }
        if let heartRate = workout.averageHeartRateBpm, heartRate > 0 {
            parts.append(
                String.localizedStringWithFormat(
                    TL(pl: "%lld bpm", en: "%lld bpm", uk: "%lld уд/хв", ru: "%lld уд/мин", es: "%lld ppm"),
                    Int(heartRate.rounded())
                )
            )
        }
        return parts.joined(separator: " · ")
    }

    private var deleteTitle: String {
        TL(
            pl: "Usuń aktywność", en: "Delete activity", uk: "Видалити активність", ru: "Удалить активность",
            es: "Eliminar actividad")
    }

    private var deleteMessage: String {
        if workout.source == .appleHealth {
            return TL(
                pl: "Usuniemy tylko wpis w Fitgram. Dane w Apple Health zostaną bez zmian.",
                en: "Only the Fitgram entry will be removed. Apple Health data stays unchanged.",
                uk: "Буде видалено лише запис у Fitgram. Дані Apple Health не зміняться.",
                ru: "Удалится только запись в Fitgram. Данные Apple Health не изменятся.",
                es: "Solo se eliminará la entrada de Fitgram. Apple Health no cambiará.")
        }
        return TL(
            pl: "Ten trening zniknie z dzisiejszego budżetu kalorii.",
            en: "This workout will be removed from today's calorie budget.",
            uk: "Це тренування зникне з денного бюджету калорій.",
            ru: "Эта тренировка исчезнет из дневного бюджета калорий.",
            es: "Este entrenamiento se quitará del presupuesto de hoy.")
    }

    private var cancelTitle: String {
        TL(pl: "Anuluj", en: "Cancel", uk: "Скасувати", ru: "Отмена", es: "Cancelar")
    }

    private var deleteAccessibilityLabel: String {
        String.localizedStringWithFormat(
            TL(
                pl: "Usuń aktywność %@", en: "Delete activity %@", uk: "Видалити активність %@",
                ru: "Удалить активность %@", es: "Eliminar actividad %@"),
            workout.activityName
        )
    }
}
