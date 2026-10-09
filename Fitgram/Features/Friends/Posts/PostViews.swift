import SwiftUI

/// Mini coloured FIT logo, no background — shown next to Premium users'
/// names.
struct PremiumMark: View {
    var height: CGFloat = 16
    /// Sits on a dark hero card (own profile) rather than a light card.
    var onDark = false

    var body: some View {
        FitgramLogoMark(color: onDark ? Tokens.Mono.hi : Tokens.Mono.Brand.logo)
            .aspectRatio(240.0 / 112.0, contentMode: .fit)
            .frame(height: height * 0.8)
            .frame(height: height)
            .accessibilityElement()
            .accessibilityLabel(Text(verbatim: "Premium"))
    }
}

/// Name + optional Premium mark, used in post headers and profiles.
struct SocialNameLabel: View {
    let name: String
    let isPremium: Bool
    var font: Font = Tokens.Font.manrope(15, weight: 800)
    var color: Color = Tokens.Palette.ink
    var markHeight: CGFloat = 16

    var body: some View {
        HStack(spacing: 6) {
            Text(name)
                .font(font)
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if isPremium {
                PremiumMark(height: markHeight)
            }
        }
    }
}

/// Dark macro card attached to a post: when it was eaten, kcal against the
/// goal, the three macros and the foods.
struct PostMacroCard: View {
    let macros: PostMacroSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                MonoLabel(text: kicker, onHero: true)
                Spacer(minLength: 0)
                Text(dateLine)
                    .font(Tokens.Font.manrope(12, weight: 700))
                    .foregroundStyle(Tokens.Mono.heroMuted)
                    .lineLimit(1)
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(verbatim: "\(macros.kcal)")
                    .font(Tokens.Font.monoNumber(44))
                    .foregroundStyle(Tokens.Mono.onHero)
                Text(TL(pl: "kcal", en: "kcal", uk: "ккал", ru: "ккал", es: "kcal"))
                    .font(Tokens.Font.manrope(14, weight: 800))
                    .foregroundStyle(Tokens.Mono.heroMuted)
                Spacer(minLength: 0)
                if let goal = macros.goalKcal, goal > 0 {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(verbatim: "\(Int((Double(macros.kcal) / Double(goal) * 100).rounded()))%")
                            .font(Tokens.Font.monoNumber(20))
                            .foregroundStyle(Tokens.Mono.hi)
                        Text(
                            TL(
                                pl: "z \(goal) kcal", en: "of \(goal) kcal", uk: "з \(goal) ккал",
                                ru: "из \(goal) ккал",
                                es: "de \(goal) kcal")
                        )
                        .font(Tokens.Font.manrope(11, weight: 700))
                        .foregroundStyle(Tokens.Mono.heroMuted)
                    }
                }
            }
            if let goal = macros.goalKcal, goal > 0 {
                MonoTicks(progress: Double(macros.kcal) / Double(goal), count: 30, height: 10)
            }
            MonoMacroRow(
                protein: Double(macros.proteinG), carbs: Double(macros.carbsG), fat: Double(macros.fatG), dark: true)
            if !macros.items.isEmpty {
                FlowLayout(horizontalSpacing: 6, verticalSpacing: 6) {
                    ForEach(macros.items, id: \.self) { item in
                        Text(item)
                            .font(Tokens.Font.manrope(11, weight: 800))
                            .foregroundStyle(Tokens.Mono.onHero)
                            .lineLimit(1)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Tokens.Mono.heroLine))
                    }
                }
            }
        }
        .monoHero(padding: 16)
        .accessibilityElement(children: .combine)
    }

    private var kicker: String {
        switch macros.scope {
        case .day:
            let meals = macros.mealCount
            return TL(
                pl: "Makro · cały dzień · \(meals) \(meals == 1 ? "posiłek" : "posiłki")",
                en: "Macros · whole day · \(meals) \(meals == 1 ? "meal" : "meals")",
                uk: "Макро · весь день · \(meals) прийоми",
                ru: "Макро · весь день · \(meals) приёма",
                es: "Macros · día completo · \(meals) comidas")
        case .meal:
            let label = macros.label ?? TL(pl: "Posiłek", en: "Meal", uk: "Прийом їжі", ru: "Приём пищи", es: "Comida")
            return TL(pl: "Makro · ", en: "Macros · ", uk: "Макро · ", ru: "Макро · ", es: "Macros · ") + label
        }
    }

    private var dateLine: String {
        let date = macros.consumedAt.formatted(.dateTime.day().month(.abbreviated).year())
        guard macros.scope == .meal else { return date }
        return "\(date) · \(macros.consumedAt.formatted(.dateTime.hour().minute()))"
    }
}

/// One post in the feed or on a profile.
struct PostCard: View {
    let post: SocialPost
    let isMine: Bool
    let onLike: () -> Void
    var onOpenAuthor: (() -> Void)?
    var onDelete: (() -> Void)?

    @State private var isDeleteConfirmed = false
    @State private var likeBounce = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            VStack(alignment: .leading, spacing: 6) {
                Text(post.title)
                    .font(Tokens.Font.monoDisplay(22))
                    .foregroundStyle(Tokens.Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if !post.body.isEmpty {
                    Text(post.body)
                        .font(Tokens.Font.manrope(14, weight: 600))
                        .foregroundStyle(Tokens.Palette.ink.opacity(0.86))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if let url = post.photoURL {
                photo(url)
            }
            if let macros = post.macros {
                PostMacroCard(macros: macros)
            } else if let activity = post.activity {
                PostActivityCard(activity: activity)
            }
            footer
        }
        .monoCard(padding: 16)
        .confirmationDialog(
            TL(
                pl: "Usunąć post?", en: "Delete this post?", uk: "Видалити пост?", ru: "Удалить пост?",
                es: "¿Eliminar la publicación?"),
            isPresented: $isDeleteConfirmed,
            titleVisibility: .visible
        ) {
            Button(TL(pl: "Usuń", en: "Delete", uk: "Видалити", ru: "Удалить", es: "Eliminar"), role: .destructive) {
                onDelete?()
            }
            Button(L("Cancel"), role: .cancel) {}
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Button {
                onOpenAuthor?()
            } label: {
                HStack(spacing: 10) {
                    FriendInitialAvatar(name: post.authorName, size: 42, dark: post.authorIsPremium)
                    VStack(alignment: .leading, spacing: 1) {
                        SocialNameLabel(name: post.authorName, isPremium: post.authorIsPremium)
                        Text(subtitle)
                            .font(Tokens.Font.manrope(12, weight: 600))
                            .foregroundStyle(Tokens.Mono.muted)
                            .lineLimit(1)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .allowsHitTesting(onOpenAuthor != nil)
            Spacer(minLength: 0)
            if isMine, onDelete != nil {
                Menu {
                    Button(role: .destructive) {
                        isDeleteConfirmed = true
                    } label: {
                        Label(
                            TL(
                                pl: "Usuń post", en: "Delete post", uk: "Видалити пост", ru: "Удалить пост",
                                es: "Eliminar publicación"),
                            systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Tokens.Mono.muted)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(Text(L("More")))
            }
        }
    }

    private var subtitle: String {
        let time = post.createdAt.formatted(.relative(presentation: .named))
        if let username = post.authorUsername { return "@\(username) · \(time)" }
        return time
    }

    private func photo(_ url: URL) -> some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: 260)
            .overlay {
                AsyncImage(url: url, transaction: Transaction(animation: Tokens.Motion.gentle)) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        MonoImagePlaceholder()
                    default:
                        LoadingShimmer(cornerRadius: 20)
                    }
                }
                .allowsHitTesting(false)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .onTapGesture(count: 2) {
                if !post.isLikedByMe { like() }
            }
            .accessibilityLabel(Text(TL(pl: "Zdjęcie", en: "Photo", uk: "Фото", ru: "Фото", es: "Foto")))
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Button(action: like) {
                HStack(spacing: 6) {
                    Image(systemName: post.isLikedByMe ? "heart.fill" : "heart")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(post.isLikedByMe ? Tokens.Mono.danger : Tokens.Palette.ink)
                        .scaleEffect(likeBounce ? 1.25 : 1)
                    Text(verbatim: "\(post.likeCount)")
                        .font(Tokens.Font.monoNumber(16))
                        .foregroundStyle(Tokens.Palette.ink)
                        .contentTransition(.numericText())
                }
                .padding(.horizontal, 14)
                .frame(height: 38)
                .background(
                    Capsule().fill(post.isLikedByMe ? Tokens.Mono.danger.opacity(0.12) : Tokens.Mono.track)
                )
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                Text(
                    post.isLikedByMe
                        ? TL(
                            pl: "Cofnij polubienie", en: "Unlike", uk: "Прибрати вподобання", ru: "Убрать лайк",
                            es: "Quitar me gusta")
                        : TL(pl: "Polub", en: "Like", uk: "Вподобати", ru: "Лайкнуть", es: "Me gusta"))
            )
            .accessibilityValue(Text(verbatim: "\(post.likeCount)"))
            Text(likesCaption)
                .font(Tokens.Font.manrope(12, weight: 700))
                .foregroundStyle(Tokens.Mono.muted)
            Spacer(minLength: 0)
        }
    }

    private var likesCaption: String {
        let count = post.likeCount
        return TL(
            pl: Self.plural(count, one: "polubienie", few: "polubienia", many: "polubień", eastSlavic: false),
            en: count == 1 ? "like" : "likes",
            uk: Self.plural(count, one: "вподобання", few: "вподобання", many: "вподобань", eastSlavic: true),
            ru: Self.plural(count, one: "лайк", few: "лайка", many: "лайков", eastSlavic: true),
            es: "me gusta")
    }

    /// Slavic plural: 1 / 2–4 / 5+, 12–14 → many. Russian and Ukrainian also
    /// use the singular for 21, 31, … (`eastSlavic`); Polish doesn't.
    static func plural(_ count: Int, one: String, few: String, many: String, eastSlavic: Bool) -> String {
        let lastTwo = count % 100
        let last = count % 10
        if count == 1 || (eastSlavic && last == 1 && lastTwo != 11) { return one }
        if (2...4).contains(last) && !(12...14).contains(lastTwo) { return few }
        return many
    }

    private func like() {
        Haptics.light()
        withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) { likeBounce = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { likeBounce = false }
        }
        onLike()
    }
}
