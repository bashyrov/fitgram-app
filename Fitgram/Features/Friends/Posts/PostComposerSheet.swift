import PhotosUI
import SwiftUI

/// New post: title, description, optional photo and optional macros from
/// any logged day or meal. Premium only, at most `PostLimits.dailyMax` a day.
struct PostComposerSheet: View {
    @Bindable var state: FriendsState
    let calorieGoalKcal: Int?
    let onDismiss: () -> Void

    @State private var title = ""
    @State private var bodyText = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var photoJPEG: Data?
    @State private var photoPreview: UIImage?
    @State private var macros: PostMacroSnapshot?
    @State private var isMacroPickerPresented = false
    @State private var isPublishing = false
    @State private var errorText: String?
    @State private var didEdit = false
    @FocusState private var focused: Field?

    private enum Field { case title, body }

    private var violations: [PostContentPolicy.Violation] {
        PostContentPolicy.violations(title: title, body: bodyText)
    }

    private var canPublish: Bool {
        violations.isEmpty && !isPublishing && state.postsLeftToday > 0
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    limitBanner
                    MonoField(label: TL(pl: "Tytuł", en: "Title", uk: "Заголовок", ru: "Заголовок", es: "Título")) {
                        TextField(
                            TL(
                                pl: "Np. Pierwszy tydzień w celu", en: "E.g. First week on target",
                                uk: "Напр. Перший тиждень у цілі", ru: "Напр. Первая неделя в цели",
                                es: "P. ej. Primera semana en el objetivo"),
                            text: $title
                        )
                        .focused($focused, equals: .title)
                        .submitLabel(.next)
                        .onSubmit { focused = .body }
                        .onChange(of: title) { _, value in
                            didEdit = true
                            if value.count > PostLimits.titleMax + 10 {
                                title = String(value.prefix(PostLimits.titleMax + 10))
                            }
                        }
                    }
                    counter(title.trimmingCharacters(in: .whitespacesAndNewlines).count, max: PostLimits.titleMax)
                    MonoField(
                        label: TL(pl: "Opis", en: "Description", uk: "Опис", ru: "Описание", es: "Descripción"),
                        multiline: true
                    ) {
                        TextEditor(text: $bodyText)
                            .focused($focused, equals: .body)
                            .scrollContentBackground(.hidden)
                            .font(Tokens.Font.manrope(15, weight: 600))
                            .frame(minHeight: 110)
                            .onChange(of: bodyText) { _, value in
                                didEdit = true
                                if value.count > PostLimits.bodyMax + 50 {
                                    bodyText = String(value.prefix(PostLimits.bodyMax + 50))
                                }
                            }
                    }
                    counter(bodyText.trimmingCharacters(in: .whitespacesAndNewlines).count, max: PostLimits.bodyMax)
                    attachments
                    if let macros {
                        ZStack(alignment: .topTrailing) {
                            PostMacroCard(macros: macros)
                            removeButton { self.macros = nil }
                        }
                    }
                    if let photoPreview {
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: photoPreview)
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity)
                                .frame(height: 220)
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            removeButton {
                                photoItem = nil
                                photoJPEG = nil
                                self.photoPreview = nil
                            }
                        }
                    }
                    problems
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.vertical, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Tokens.Palette.background.ignoresSafeArea())
            .monoNavigationTitle(
                TL(pl: "Nowy post", en: "New post", uk: "Новий пост", ru: "Новый пост", es: "Nueva publicación")
            )
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    MonoNavIcon(systemName: "xmark", accessibilityLabel: L("Zamknij"), action: onDismiss)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    MonoNavPill(
                        title: isPublishing
                            ? "…"
                            : TL(pl: "Opublikuj", en: "Publish", uk: "Опублікувати", ru: "Опубликовать", es: "Publicar")
                    ) {
                        Task { await publish() }
                    }
                    .disabled(!canPublish)
                    .opacity(canPublish ? 1 : 0.45)
                }
            }
            .sheet(isPresented: $isMacroPickerPresented) {
                PostMacroPickerSheet(calorieGoalKcal: calorieGoalKcal) { picked in
                    macros = picked
                    isMacroPickerPresented = false
                } onDismiss: {
                    isMacroPickerPresented = false
                }
            }
            .onChange(of: photoItem) { _, item in
                Task { await loadPhoto(item) }
            }
            .onAppear { focused = .title }
        }
        .toastSurface()
    }

    private var limitBanner: some View {
        HStack(spacing: 10) {
            MonoIconBox(systemName: "square.and.pencil", style: .dark, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(
                    TL(
                        pl: "Dziś: \(state.postsPublishedToday) z \(PostLimits.dailyMax) postów",
                        en: "Today: \(state.postsPublishedToday) of \(PostLimits.dailyMax) posts",
                        uk: "Сьогодні: \(state.postsPublishedToday) з \(PostLimits.dailyMax) постів",
                        ru: "Сегодня: \(state.postsPublishedToday) из \(PostLimits.dailyMax) постов",
                        es: "Hoy: \(state.postsPublishedToday) de \(PostLimits.dailyMax) publicaciones")
                )
                .font(Tokens.Font.manrope(14, weight: 800))
                .foregroundStyle(Tokens.Palette.ink)
                Text(
                    TL(
                        pl: "Post zobaczą Twoi znajomi. Bez wulgaryzmów i linków.",
                        en: "Your friends will see this post. No profanity or links.",
                        uk: "Пост побачать твої друзі. Без лайки й посилань.",
                        ru: "Пост увидят твои друзья. Без мата и ссылок.",
                        es: "Tus amigos verán la publicación. Sin groserías ni enlaces.")
                )
                .font(Tokens.Font.manrope(12, weight: 600))
                .foregroundStyle(Tokens.Mono.muted)
                .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .monoCard(padding: 14)
    }

    private var attachments: some View {
        HStack(spacing: 8) {
            PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
                attachmentLabel(
                    icon: "photo",
                    title: photoJPEG == nil
                        ? TL(pl: "Zdjęcie", en: "Photo", uk: "Фото", ru: "Фото", es: "Foto")
                        : TL(
                            pl: "Zmień zdjęcie", en: "Change photo", uk: "Змінити фото", ru: "Сменить фото",
                            es: "Cambiar foto"))
            }
            .buttonStyle(.plain)
            Button {
                isMacroPickerPresented = true
            } label: {
                attachmentLabel(
                    icon: "chart.pie",
                    title: macros == nil
                        ? TL(
                            pl: "Dodaj makro", en: "Add macros", uk: "Додати макро", ru: "Добавить макро",
                            es: "Añadir macros")
                        : TL(
                            pl: "Zmień makro", en: "Change macros", uk: "Змінити макро", ru: "Сменить макро",
                            es: "Cambiar macros"))
            }
            .buttonStyle(.plain)
        }
    }

    private func attachmentLabel(icon: String, title: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 14, weight: .bold))
            Text(title).lineLimit(1).minimumScaleFactor(0.8)
        }
        .font(Tokens.Font.manrope(14, weight: 800))
        .foregroundStyle(Tokens.Palette.ink)
        .frame(maxWidth: .infinity)
        .frame(height: 46)
        .overlay(Capsule().stroke(Tokens.Mono.line2, lineWidth: 1))
        .contentShape(Capsule())
    }

    private func removeButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(Tokens.Mono.onHero)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Tokens.Mono.hero))
                .overlay(Circle().stroke(Tokens.Palette.background, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .offset(x: 8, y: -8)
        .accessibilityLabel(Text(TL(pl: "Usuń", en: "Remove", uk: "Прибрати", ru: "Убрать", es: "Quitar")))
    }

    private func counter(_ count: Int, max: Int) -> some View {
        Text(verbatim: "\(count) / \(max)")
            .font(Tokens.Font.manrope(11, weight: 700))
            .foregroundStyle(count > max ? Tokens.Mono.danger : Tokens.Mono.muted)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.horizontal, 6)
    }

    @ViewBuilder
    private var problems: some View {
        let shown = didEdit ? violations : []
        if !shown.isEmpty || errorText != nil {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(shown, id: \.message) { violation in
                    problemRow(violation.message)
                }
                if let errorText {
                    problemRow(errorText)
                }
            }
        }
    }

    private func problemRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 13, weight: .bold))
            Text(text)
                .font(Tokens.Font.manrope(12, weight: 700))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(Tokens.Mono.danger)
        .padding(.horizontal, 6)
    }

    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item, let data = try? await item.loadTransferable(type: Data.self),
            let image = UIImage(data: data)
        else { return }
        let scaled = Self.downscale(image, maxSide: 1440)
        photoPreview = scaled
        photoJPEG = scaled.jpegData(compressionQuality: 0.78)
    }

    private static func downscale(_ image: UIImage, maxSide: CGFloat) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        guard longest > maxSide else { return image }
        let scale = maxSide / longest
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    private func publish() async {
        didEdit = true
        guard canPublish else { return }
        isPublishing = true
        defer { isPublishing = false }
        do {
            try await state.publish(PostDraft(title: title, body: bodyText, photoJPEG: photoJPEG, macros: macros))
            Haptics.success()
            onDismiss()
        } catch let error as PostError {
            Haptics.error()
            errorText = Self.message(for: error)
        } catch {
            Haptics.error()
            errorText = Self.message(for: .network(String(describing: error)))
        }
    }

    static func message(for error: PostError) -> String {
        switch error {
        case .premiumRequired:
            return TL(
                pl: "Posty są dostępne w Premium.", en: "Posts are a Premium feature.", uk: "Пости доступні в Premium.",
                ru: "Посты доступны в Premium.", es: "Las publicaciones son de Premium.")
        case .dailyLimitReached:
            return TL(
                pl: "Limit \(PostLimits.dailyMax) postów na dziś wykorzystany. Wróć jutro!",
                en: "You've used today's \(PostLimits.dailyMax) posts. Come back tomorrow!",
                uk: "Ліміт \(PostLimits.dailyMax) постів на сьогодні вичерпано. Повертайся завтра!",
                ru: "Лимит \(PostLimits.dailyMax) постов на сегодня исчерпан. Возвращайся завтра!",
                es: "Ya usaste las \(PostLimits.dailyMax) publicaciones de hoy. ¡Vuelve mañana!")
        case .contentRejected:
            return TL(
                pl: "Popraw tekst posta.", en: "Please fix the post text.", uk: "Виправ текст поста.",
                ru: "Исправь текст поста.", es: "Corrige el texto de la publicación.")
        case .notFound, .network:
            return TL(
                pl: "Nie udało się opublikować. Spróbuj za chwilę.", en: "Couldn't publish. Try again in a moment.",
                uk: "Не вдалося опублікувати. Спробуй за хвилину.", ru: "Не удалось опубликовать. Попробуй чуть позже.",
                es: "No se pudo publicar. Inténtalo en un momento.")
        }
    }
}

/// Pick a logged day (whole day or one meal) to attach to a post.
struct PostMacroPickerSheet: View {
    let calorieGoalKcal: Int?
    let onPick: (PostMacroSnapshot) -> Void
    let onDismiss: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var day = Date()
    @State private var meals: [MealEntry] = []

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
                    if meals.isEmpty {
                        MonoHint(
                            text: TL(
                                pl: "Tego dnia nic nie zapisano. Wybierz inny dzień.",
                                en: "Nothing was logged that day. Pick another day.",
                                uk: "Цього дня нічого не записано. Обери інший день.",
                                ru: "В этот день ничего не записано. Выбери другой день.",
                                es: "Ese día no se registró nada. Elige otro día."))
                    } else {
                        if let whole = PostMacroBuilder.day(meals, goalKcal: calorieGoalKcal) {
                            option(
                                title: TL(
                                    pl: "Cały dzień", en: "Whole day", uk: "Весь день", ru: "Весь день",
                                    es: "Día completo"),
                                snapshot: whole)
                        }
                        ForEach(meals, id: \.id) { meal in
                            option(
                                title: PostMacroBuilder.mealLabel(meal.mealType) + " · "
                                    + meal.consumedAt.formatted(.dateTime.hour().minute()),
                                snapshot: PostMacroBuilder.meal(meal, goalKcal: calorieGoalKcal))
                        }
                    }
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.vertical, 12)
            }
            .background(Tokens.Palette.background.ignoresSafeArea())
            .monoNavigationTitle(
                TL(
                    pl: "Makro do posta", en: "Macros for the post", uk: "Макро для поста",
                    ru: "Макро для поста", es: "Macros para la publicación")
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

    private func option(title: String, snapshot: PostMacroSnapshot) -> some View {
        Button {
            Haptics.selection()
            onPick(snapshot)
        } label: {
            MonoRow(
                icon: snapshot.scope == .day ? "calendar" : "fork.knife",
                iconStyle: snapshot.scope == .day ? .dark : .track,
                title: title,
                sub: Self.summary(snapshot)
            ) {
                MonoChevron()
            }
        }
        .buttonStyle(.plain)
        .monoRowsCard()
    }

    private func reload() {
        meals = PostMacroBuilder.meals(on: day, in: modelContext)
    }

    /// "1535 kcal · B 79 g · W 159 g · T 63 g" in the app language.
    static func summary(_ snapshot: PostMacroSnapshot) -> String {
        let letters = TL(pl: "B W T", en: "P C F", uk: "Б В Ж", ru: "Б У Ж", es: "P C G").split(separator: " ")
        let kcal = TL(pl: "kcal", en: "kcal", uk: "ккал", ru: "ккал", es: "kcal")
        let grams = TL(pl: "g", en: "g", uk: "г", ru: "г", es: "g")
        let values = [snapshot.proteinG, snapshot.carbsG, snapshot.fatG]
        let macros = zip(letters, values).map { "\($0) \($1) \(grams)" }
        return (["\(snapshot.kcal) \(kcal)"] + macros).joined(separator: " · ")
    }
}
