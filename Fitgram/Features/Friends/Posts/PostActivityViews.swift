import SwiftUI

/// Dark activity card attached to a post: what, when, how long, kcal burned
/// and the extras (distance, steps, heart rate).
struct PostActivityCard: View {
    let activity: PostActivitySnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                MonoLabel(
                    text: TL(
                        pl: "Aktywność · ", en: "Activity · ", uk: "Активність · ", ru: "Активность · ",
                        es: "Actividad · ") + activity.name,
                    onHero: true)
                Spacer(minLength: 0)
                Text(dateLine)
                    .font(Tokens.Font.manrope(12, weight: 700))
                    .foregroundStyle(Tokens.Mono.heroMuted)
                    .lineLimit(1)
            }
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: activity.symbol)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Tokens.Mono.onHi)
                    .frame(width: 58, height: 58)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Tokens.Mono.hi))
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(verbatim: "\(activity.durationMinutes)")
                        .font(Tokens.Font.monoNumber(44))
                        .foregroundStyle(Tokens.Mono.onHero)
                    Text(TL(pl: "min", en: "min", uk: "хв", ru: "мин", es: "min"))
                        .font(Tokens.Font.manrope(14, weight: 800))
                        .foregroundStyle(Tokens.Mono.heroMuted)
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(verbatim: "−\(activity.kcalBurned)")
                        .font(Tokens.Font.monoNumber(22))
                        .foregroundStyle(Tokens.Mono.hi)
                    Text(
                        TL(
                            pl: "kcal spalone", en: "kcal burned", uk: "ккал спалено", ru: "ккал сожжено",
                            es: "kcal quemadas")
                    )
                    .font(Tokens.Font.manrope(11, weight: 700))
                    .foregroundStyle(Tokens.Mono.heroMuted)
                }
            }
            if !extras.isEmpty {
                HStack(spacing: 6) {
                    ForEach(extras, id: \.label) { extra in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(extra.label)
                                .font(Tokens.Font.manrope(11, weight: 800))
                                .textCase(.uppercase)
                                .tracking(1.1)
                                .opacity(0.75)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Text(extra.value)
                                .font(Tokens.Font.monoNumber(18))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .foregroundStyle(Tokens.Mono.onHero)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Tokens.Mono.heroLine))
                    }
                }
            }
        }
        .monoHero(padding: 16)
        .accessibilityElement(children: .combine)
    }

    private struct Extra {
        let label: String
        let value: String
    }

    private var extras: [Extra] {
        var result: [Extra] = []
        if let meters = activity.distanceMeters {
            result.append(
                Extra(
                    label: TL(pl: "Dystans", en: "Distance", uk: "Дистанція", ru: "Дистанция", es: "Distancia"),
                    value: meters >= 1000 ? String(format: "%.1f km", meters / 1000) : "\(Int(meters)) m"))
        }
        if let steps = activity.steps {
            result.append(
                Extra(label: TL(pl: "Kroki", en: "Steps", uk: "Кроки", ru: "Шаги", es: "Pasos"), value: "\(steps)"))
        }
        if let pulse = activity.averageHeartRate {
            result.append(
                Extra(
                    label: TL(pl: "Tętno", en: "Heart rate", uk: "Пульс", ru: "Пульс", es: "Pulso"), value: "\(pulse)"))
        }
        return result
    }

    private var dateLine: String {
        activity.startedAt.formatted(.dateTime.day().month(.abbreviated).year()) + " · "
            + activity.startedAt.formatted(.dateTime.hour().minute())
    }
}

/// Pick a logged workout from any day to attach to a post.
struct PostActivityPickerSheet: View {
    let userRemoteID: String
    let onPick: (PostActivitySnapshot) -> Void
    let onDismiss: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var day = Date()
    @State private var workouts: [WorkoutEntry] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    DatePicker(
                        TL(pl: "Dzień", en: "Day", uk: "День", ru: "День", es: "Día"),
                        selection: $day,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .tint(Tokens.Mono.strong)
                    .monoCard(padding: 12)
                    if workouts.isEmpty {
                        MonoHint(
                            text: TL(
                                pl: "Tego dnia nie ma treningów. Wybierz inny dzień.",
                                en: "No workouts that day. Pick another day.",
                                uk: "Цього дня немає тренувань. Обери інший день.",
                                ru: "В этот день нет тренировок. Выбери другой день.",
                                es: "No hay entrenamientos ese día. Elige otro día."))
                    } else {
                        ForEach(workouts, id: \.id) { workout in
                            option(PostActivityBuilder.activity(workout))
                        }
                    }
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.vertical, 12)
            }
            .background(Tokens.Palette.background.ignoresSafeArea())
            .monoNavigationTitle(
                TL(
                    pl: "Aktywność do posta", en: "Activity for the post", uk: "Активність для поста",
                    ru: "Активность для поста", es: "Actividad para la publicación")
            )
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    MonoNavIcon(systemName: "xmark", accessibilityLabel: L("Zamknij"), action: onDismiss)
                }
            }
            .onAppear { reload() }
            .onChange(of: day) { _, _ in reload() }
        }
    }

    private func option(_ snapshot: PostActivitySnapshot) -> some View {
        Button {
            Haptics.selection()
            onPick(snapshot)
        } label: {
            MonoRow(
                icon: snapshot.symbol,
                iconStyle: .dark,
                title: snapshot.name + " · " + snapshot.startedAt.formatted(.dateTime.hour().minute()),
                sub: TL(
                    pl: "\(snapshot.durationMinutes) min · \(snapshot.kcalBurned) kcal",
                    en: "\(snapshot.durationMinutes) min · \(snapshot.kcalBurned) kcal",
                    uk: "\(snapshot.durationMinutes) хв · \(snapshot.kcalBurned) ккал",
                    ru: "\(snapshot.durationMinutes) мин · \(snapshot.kcalBurned) ккал",
                    es: "\(snapshot.durationMinutes) min · \(snapshot.kcalBurned) kcal")
            ) {
                MonoChevron()
            }
        }
        .buttonStyle(.plain)
        .monoRowsCard()
    }

    private func reload() {
        workouts = PostActivityBuilder.workouts(on: day, userRemoteID: userRemoteID, in: modelContext)
    }
}
