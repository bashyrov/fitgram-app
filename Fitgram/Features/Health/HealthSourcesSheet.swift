import SwiftUI

/// "Źródła i metodologia": the published sources behind the app's health
/// numbers and tips (App Review guideline 1.4.1). Opens on the topics of the
/// screen it came from, with every other topic below.
struct HealthSourcesSheet: View {
    var focus: [HealthTopic] = []
    let onDismiss: () -> Void

    @Environment(\.openURL) private var openURL

    private var orderedTopics: [HealthTopic] {
        focus + HealthTopic.allCases.filter { !focus.contains($0) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    MonoH1(text: Self.screenTitle, sub: Self.intro)
                    disclaimer
                        .padding(.top, 14)
                    ForEach(orderedTopics) { topic in
                        MonoSectionHeader(title: topic.title) { EmptyView() }
                            .padding(.horizontal, 6)
                            .padding(.top, 22)
                            .padding(.bottom, 12)
                        VStack(spacing: 0) {
                            ForEach(Array(topic.sources.enumerated()), id: \.element.id) { index, source in
                                if index > 0 { MonoRowDivider() }
                                sourceRow(source)
                            }
                        }
                        .monoRowsCard()
                    }
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.bottom, 34)
            }
            .scrollIndicators(.hidden)
            .background(Tokens.Palette.background.ignoresSafeArea())
            .monoNavigationTitle(Self.navigationTitle)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    MonoNavText(title: Self.closeText, action: onDismiss)
                }
            }
        }
    }

    private func sourceRow(_ source: HealthSource) -> some View {
        Button {
            Haptics.light()
            openURL(source.url)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(source.title)
                        .font(Tokens.Font.manrope(14, weight: 700))
                        .foregroundStyle(Tokens.Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(source.publisher) · \(String(source.year))")
                        .font(Tokens.Font.manrope(12, weight: 600))
                        .foregroundStyle(Tokens.Mono.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(source.url.host() ?? source.url.absoluteString)
                        .font(Tokens.Font.manrope(12, weight: 700))
                        .foregroundStyle(Tokens.Palette.accent)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Tokens.Mono.muted)
                    .padding(.top, 3)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text(Self.opensInBrowser))
    }

    private var disclaimer: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "stethoscope")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Tokens.Palette.ink)
            Text(Self.disclaimerText)
                .font(Tokens.Font.manrope(13, weight: 600))
                .foregroundStyle(Tokens.Palette.ink)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .monoCard(padding: 16)
    }
}

// MARK: - Copy

extension HealthSourcesSheet {
    static var navigationTitle: String {
        TL(pl: "Źródła", en: "Sources", uk: "Джерела", ru: "Источники", es: "Fuentes")
    }

    static var screenTitle: String {
        TL(
            pl: "Źródła i metodologia", en: "Sources and methods", uk: "Джерела та методика",
            ru: "Источники и методика", es: "Fuentes y metodología")
    }

    fileprivate static var intro: String {
        TL(
            pl: "Na czym opierają się wyliczenia i porady w Fitgram. Dotknij źródła, aby je otworzyć.",
            en: "What Fitgram's calculations and tips are based on. Tap a source to open it.",
            uk: "На чому ґрунтуються розрахунки та поради у Fitgram. Торкнися джерела, щоб відкрити його.",
            ru: "На чём основаны расчёты и советы в Fitgram. Нажми на источник, чтобы открыть его.",
            es: "En qué se basan los cálculos y consejos de Fitgram. Toca una fuente para abrirla.")
    }

    fileprivate static var disclaimerText: String {
        TL(
            pl:
                "Fitgram nie jest wyrobem medycznym i nie udziela porad medycznych. Wartości są szacunkami dla zdrowych dorosłych. "
                + "W razie chorób, ciąży lub zaburzeń odżywiania skonsultuj się z lekarzem lub dietetykiem.",
            en:
                "Fitgram is not a medical device and does not give medical advice. Values are estimates for healthy adults. "
                + "If you have a medical condition, are pregnant or have an eating disorder, talk to a doctor or dietitian.",
            uk:
                "Fitgram не є медичним виробом і не надає медичних порад. Значення — це оцінки для здорових дорослих. "
                + "Якщо маєш захворювання, вагітність чи розлад харчування, порадься з лікарем або дієтологом.",
            ru:
                "Fitgram не является медицинским изделием и не даёт медицинских советов. Значения — это оценки для здоровых взрослых. "
                + "При заболеваниях, беременности или расстройствах пищевого поведения посоветуйся с врачом или диетологом.",
            es:
                "Fitgram no es un dispositivo médico y no ofrece consejo médico. Los valores son estimaciones para adultos sanos. "
                + "Si tienes una enfermedad, estás embarazada o tienes un trastorno alimentario, consulta a un médico o dietista."
        )
    }

    fileprivate static var closeText: String {
        TL(pl: "Zamknij", en: "Close", uk: "Закрити", ru: "Закрыть", es: "Cerrar")
    }

    fileprivate static var opensInBrowser: String {
        TL(
            pl: "Otwiera źródło w przeglądarce", en: "Opens the source in the browser",
            uk: "Відкриває джерело в браузері", ru: "Открывает источник в браузере",
            es: "Abre la fuente en el navegador")
    }
}

/// Inline "Źródła: Mifflin–St Jeor 1990 · EFSA 2013" link under a number or
/// tip. Opens the sources sheet focused on the given topics.
struct HealthSourcesLink: View {
    let topics: [HealthTopic]

    @State private var isPresented = false

    private var names: String {
        var seen = Set<String>()
        let all = topics.flatMap(\.sources).filter { seen.insert($0.shortName).inserted }
        return all.prefix(3).map(\.shortName).joined(separator: " · ")
    }

    var body: some View {
        Button {
            Haptics.light()
            isPresented = true
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: "book.closed")
                    .font(.system(size: 11, weight: .bold))
                Text("\(HealthSourcesSheet.navigationTitle): \(names)")
                    .font(Tokens.Font.manrope(12, weight: 700))
                    .underline()
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(Tokens.Mono.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(HealthSourcesSheet.screenTitle))
        .sheet(isPresented: $isPresented) {
            HealthSourcesSheet(focus: topics, onDismiss: { isPresented = false })
        }
    }
}
