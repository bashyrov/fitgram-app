import SwiftUI

/// First onboarding screen: full-bleed graphite with the product promise
/// ("snap a photo, we count the rest") shown on a sample scan result.
struct WelcomeStepView: View {
    let onContinue: () -> Void
    var onSkip: (() -> Void)?

    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.top, 12)
            Spacer(minLength: 16)
            ScanPreviewCard()
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 24)
                .rotationEffect(.degrees(appeared ? -2 : 0))
            Spacer(minLength: 24)
            headline
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)
            methods
                .padding(.top, 20)
                .opacity(appeared ? 1 : 0)
            MonoButton(title: L("Zacznijmy"), kind: .hi, action: onContinue)
                .accessibilityIdentifier(A11yID.Onboarding.welcomeStart)
                .padding(.top, 24)
                .padding(.bottom, 8)
        }
        .padding(.horizontal, Tokens.Space.screenPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(backdrop.ignoresSafeArea())
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.1)) {
                appeared = true
            }
        }
    }

    private var backdrop: some View {
        ZStack {
            Tokens.Mono.hero
            RadialGradient(
                colors: [Tokens.Mono.hi.opacity(0.35), .clear],
                center: UnitPoint(x: 0.85, y: 0.25),
                startRadius: 0,
                endRadius: 420
            )
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            FitgramLogoMark(color: Tokens.Mono.hi)
                .frame(width: 44, height: 22)
            Text(verbatim: "FITGRAM")
                .font(Tokens.Font.monoDisplay(20))
                .foregroundStyle(Tokens.Mono.onHero)
        }
        .accessibilityElement(children: .combine)
    }

    private var headline: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(
                TL(
                    pl: "Zrób zdjęcie.\nResztę policzymy.",
                    en: "Snap your plate.\nWe'll do the math.",
                    uk: "Сфотографуй.\nРешту порахуємо.",
                    ru: "Сфотографируй.\nОстальное посчитаем.",
                    es: "Haz una foto.\nNosotros contamos.")
            )
            .font(Tokens.Font.monoDisplay(38))
            .textCase(.uppercase)
            .foregroundStyle(Tokens.Mono.onHero)
            .lineSpacing(-2)
            .minimumScaleFactor(0.7)
            .fixedSize(horizontal: false, vertical: true)
            Text(
                TL(
                    pl: "Kalorie i makro z jednego zdjęcia. Coach Ola podpowie resztę pod Twój cel.",
                    en: "Calories and macros from a single photo. Coach Ola handles the rest for your goal.",
                    uk: "Калорії та макро з одного фото. Коуч Оля підкаже решту під твою ціль.",
                    ru: "Калории и БЖУ по одному фото. Коуч Оля подскажет остальное под твою цель.",
                    es: "Calorías y macros con una sola foto. La coach Ola se encarga del resto según tu objetivo.")
            )
            .font(Tokens.Font.manrope(15, weight: 600))
            .foregroundStyle(Tokens.Mono.heroMuted)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// The other ways to log, as quiet chips.
    private var methods: some View {
        HStack(spacing: 6) {
            methodChip("camera.fill", TL(pl: "Zdjęcie", en: "Photo", uk: "Фото", ru: "Фото", es: "Foto"))
            methodChip("mic.fill", TL(pl: "Głos", en: "Voice", uk: "Голос", ru: "Голос", es: "Voz"))
            methodChip(
                "barcode.viewfinder", TL(pl: "Kod", en: "Barcode", uk: "Штрихкод", ru: "Штрихкод", es: "Código"))
            methodChip("text.cursor", TL(pl: "Tekst", en: "Text", uk: "Текст", ru: "Текст", es: "Texto"))
        }
    }

    private func methodChip(_ symbol: String, _ title: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .bold))
            Text(title)
                .font(Tokens.Font.manrope(12, weight: 800))
                .lineLimit(1)
        }
        .foregroundStyle(Tokens.Mono.onHero)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Capsule().stroke(Tokens.Mono.heroLine, lineWidth: 1))
    }
}

/// Illustrative scan result: viewfinder corners around a plate, then the
/// dish with calories and macros, plus a streak chip. Sample data only.
private struct ScanPreviewCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Tokens.Mono.onHero.opacity(0.06))
                Text(verbatim: "🥟")
                    .font(.system(size: 64))
                ViewfinderCorners()
                    .stroke(Tokens.Mono.hi, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .padding(14)
            }
            .frame(height: 150)
            .overlay(alignment: .topTrailing) {
                streakChip.padding(10)
            }

            HStack(alignment: .center, spacing: 4) {
                Text(
                    TL(
                        pl: "Pierogi z mięsem", en: "Meat pierogi", uk: "Вареники з м'ясом", ru: "Вареники с мясом",
                        es: "Pierogi de carne")
                )
                .font(Tokens.Font.manrope(16, weight: 800))
                .foregroundStyle(Tokens.Mono.onHero)
                Spacer(minLength: 8)
                Text(verbatim: "420")
                    .font(Tokens.Font.monoDisplay(26))
                    .foregroundStyle(Tokens.Mono.hi)
                Text(verbatim: "kcal")
                    .font(Tokens.Font.manrope(12, weight: 800))
                    .foregroundStyle(Tokens.Mono.heroMuted)
            }
            HStack(spacing: 6) {
                macro(TL(pl: "B", en: "P", uk: "Б", ru: "Б", es: "P"), 18, 0.55)
                macro(TL(pl: "W", en: "C", uk: "В", ru: "У", es: "C"), 52, 0.8)
                macro(TL(pl: "T", en: "F", uk: "Ж", ru: "Ж", es: "G"), 14, 0.4)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Mono.Radius.hero, style: .continuous)
                .fill(Tokens.Mono.onHero.opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Mono.Radius.hero, style: .continuous)
                .stroke(Tokens.Mono.heroLine, lineWidth: 1)
        )
        .accessibilityHidden(true)
    }

    private var streakChip: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .font(.system(size: 11, weight: .bold))
            Text(verbatim: "12")
                .font(Tokens.Font.manrope(12, weight: 800))
        }
        .foregroundStyle(Tokens.Mono.onHi)
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(Capsule().fill(Tokens.Mono.hi))
    }

    private func macro(_ letter: String, _ grams: Int, _ fill: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: "\(letter)  \(grams) g")
                .font(Tokens.Font.manrope(12, weight: 800))
                .foregroundStyle(Tokens.Mono.onHero)
            GeometryReader { proxy in
                Capsule()
                    .fill(Tokens.Mono.heroLine)
                    .overlay(alignment: .leading) {
                        Capsule().fill(Tokens.Mono.hi).frame(width: proxy.size.width * fill)
                    }
            }
            .frame(height: 5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Four rounded corner brackets, like a camera viewfinder.
private struct ViewfinderCorners: Shape {
    func path(in rect: CGRect) -> Path {
        let arm = min(rect.width, rect.height) * 0.16
        var path = Path()
        let corners: [(point: CGPoint, inward: CGVector)] = [
            (CGPoint(x: rect.minX, y: rect.minY), CGVector(dx: 1, dy: 1)),
            (CGPoint(x: rect.maxX, y: rect.minY), CGVector(dx: -1, dy: 1)),
            (CGPoint(x: rect.minX, y: rect.maxY), CGVector(dx: 1, dy: -1)),
            (CGPoint(x: rect.maxX, y: rect.maxY), CGVector(dx: -1, dy: -1)),
        ]
        for corner in corners {
            let point = corner.point
            path.move(to: CGPoint(x: point.x, y: point.y + corner.inward.dy * arm))
            path.addLine(to: point)
            path.addLine(to: CGPoint(x: point.x + corner.inward.dx * arm, y: point.y))
        }
        return path
    }
}
