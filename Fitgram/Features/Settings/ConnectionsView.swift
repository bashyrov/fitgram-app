import SwiftUI

struct ConnectionsView: View {
    let user: User?
    let weightService: WeightService?
    let workoutService: WorkoutService?
    let onDismiss: () -> Void

    @State private var isImportingHealth = false
    @State private var statusText: String?
    @State private var healthWorkoutsEnabled = HealthWorkoutConnectionStore.isEnabled

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    MonoH1(text: heroTitle, sub: heroSubtitle)
                    providerRows
                        .padding(.top, 16)
                    if let statusText {
                        statusCard(statusText)
                            .padding(.top, 10)
                    }
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.bottom, Tokens.Space.lg)
            }
            .scrollIndicators(.hidden)
            .background(Tokens.Palette.background.ignoresSafeArea())
            .monoNavigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    MonoNavText(title: closeTitle, action: onDismiss)
                }
            }
        }
    }

    private var providerRows: some View {
        VStack(spacing: 0) {
            providerRow(.appleHealth)
            MonoRowDivider()
            providerRow(.strava)
            MonoRowDivider()
            providerRow(.oura)
            MonoRowDivider()
            providerRow(.garmin)
            MonoRowDivider()
            providerRow(.whoop)
        }
        .monoRowsCard()
    }

    @ViewBuilder
    private func providerRow(_ provider: Provider) -> some View {
        if provider == .appleHealth {
            MonoRow(
                icon: provider.symbol,
                iconStyle: .track,
                title: provider.title,
                sub: healthWorkoutsEnabled ? provider.subtitle + "\n" + autoSyncHint : provider.subtitle
            ) {
                Button {
                    Task { await importHealth() }
                } label: {
                    HStack(spacing: 6) {
                        if isImportingHealth {
                            ProgressView()
                                .controlSize(.small)
                                .tint(Tokens.Mono.onHero)
                        }
                        Text(isImportingHealth ? importingLabel : connectHealthLabel)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.8)
                    }
                }
                .buttonStyle(MonoButtonStyle(kind: .dark, height: 38, fullWidth: false))
                .frame(maxWidth: 150)
                .disabled(isImportingHealth || user == nil || (weightService == nil && workoutService == nil))
            }
        } else {
            MonoRow(icon: provider.symbol, iconStyle: .track, title: provider.title, sub: provider.subtitle) {
                Text(soonLabel)
                    .font(Tokens.Font.manrope(11, weight: 800))
                    .foregroundStyle(Tokens.Palette.ink)
                    .padding(.horizontal, 9)
                    .frame(height: 26)
                    .background(Capsule().fill(Tokens.Mono.track))
            }
        }
    }

    private func statusCard(_ text: String) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: healthWorkoutsEnabled ? "checkmark" : "info.circle")
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(healthWorkoutsEnabled ? Tokens.Palette.success : Tokens.Mono.muted)
            Text(text)
                .font(Tokens.Font.manrope(12, weight: 600))
                .foregroundStyle(Tokens.Mono.muted)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .monoCard(padding: 16)
    }

    private func importHealth() async {
        guard let user, !isImportingHealth else { return }
        isImportingHealth = true
        defer { isImportingHealth = false }
        let health = HealthKitService()
        var weightResult: HealthImporter.ImportResult?
        if let weightService {
            weightResult = await HealthImporter(
                health: health,
                weightService: weightService
            ).runImport(for: user.remoteID)
        }
        let workoutResult: HealthWorkoutImporter.ImportResult?
        if let workoutService {
            workoutResult = await HealthWorkoutImporter(
                health: health,
                workoutService: workoutService
            ).importRecentDays(for: user.remoteID)
        } else {
            workoutResult = nil
        }
        if case .imported = workoutResult {
            HealthWorkoutConnectionStore.isEnabled = true
            HealthWorkoutConnectionStore.markAutoSynced()
            NotificationCenter.default.post(name: Notification.Name("FitgramHealthWorkoutsConnected"), object: nil)
        } else if case .noNewSamples = workoutResult {
            HealthWorkoutConnectionStore.isEnabled = true
            HealthWorkoutConnectionStore.markAutoSynced()
            NotificationCenter.default.post(name: Notification.Name("FitgramHealthWorkoutsConnected"), object: nil)
        } else if case .denied = workoutResult {
            HealthWorkoutConnectionStore.isEnabled = false
        }
        healthWorkoutsEnabled = HealthWorkoutConnectionStore.isEnabled
        statusText = Self.healthMessage(weight: weightResult, workouts: workoutResult)
        Haptics.light()
    }
}

extension ConnectionsView {
    fileprivate enum Provider: CaseIterable {
        case appleHealth
        case strava
        case oura
        case garmin
        case whoop

        var title: String {
            switch self {
            case .appleHealth: "Apple Health"
            case .strava: "Strava"
            case .oura: "Oura"
            case .garmin: "Garmin"
            case .whoop: "Whoop"
            }
        }

        var symbol: String {
            switch self {
            case .appleHealth: "heart"
            case .strava: "figure.run"
            case .oura: "waveform.path.ecg"
            case .garmin: "clock"
            case .whoop: "bolt"
            }
        }

        var tint: Color {
            switch self {
            case .appleHealth: Tokens.Palette.error
            case .strava: Tokens.Palette.warning
            case .oura: Tokens.Palette.primary
            case .garmin: Tokens.Palette.accent
            case .whoop: Tokens.Palette.primary
            }
        }

        var subtitle: String {
            switch self {
            case .appleHealth:
                return TL(
                    pl: "Automatycznie pobiera treningi, aktywne kcal, dystans i wagę z Health.",
                    en: "Automatically imports workouts, active kcal, distance, and weight from Health.",
                    uk: "Автоматично імпортує тренування, активні ккал, дистанцію і вагу з Health.",
                    ru: "Автоматически импортирует тренировки, активные ккал, дистанцию и вес из Health.",
                    es: "Importa entrenamientos, kcal activas, distancia y peso desde Health.")
            case .strava, .oura, .garmin, .whoop:
                return TL(
                    pl: "Wymaga OAuth i backend callback. UI jest gotowe.",
                    en: "Requires OAuth and backend callback. UI is ready.",
                    uk: "Потрібні OAuth і backend callback. UI готовий.",
                    ru: "Нужны OAuth и backend callback. UI готов.", es: "Requiere OAuth y backend callback. UI listo.")
            }
        }
    }

    fileprivate var title: String {
        TL(pl: "Połączenia", en: "Connections", uk: "Підключення", ru: "Подключения", es: "Conexiones")
    }
    fileprivate var closeTitle: String { TL(pl: "Zamknij", en: "Close", uk: "Закрити", ru: "Закрыть", es: "Cerrar") }
    fileprivate var heroTitle: String {
        TL(
            pl: "Integracje aktywności", en: "Activity integrations", uk: "Інтеграції активності",
            ru: "Интеграции активности", es: "Integraciones de actividad")
    }
    fileprivate var heroSubtitle: String {
        TL(
            pl: "Treningi zwiększą dzienny budżet kalorii i pojawią się w osi dnia.",
            en: "Workouts increase the daily calorie budget and appear in Today.",
            uk: "Тренування збільшують денний бюджет калорій і з'являються сьогодні.",
            ru: "Тренировки увеличивают дневной бюджет калорий и появляются на главной.",
            es: "Los entrenamientos aumentan el presupuesto diario y aparecen en Hoy.")
    }
    fileprivate var appleHealthBadge: String {
        healthWorkoutsEnabled
            ? TL(pl: "Auto", en: "Auto", uk: "Авто", ru: "Авто", es: "Auto")
            : TL(pl: "Gotowe", en: "Ready", uk: "Готово", ru: "Готово", es: "Listo")
    }
    fileprivate var soonLabel: String { TL(pl: "Backend", en: "Backend", uk: "Backend", ru: "Backend", es: "Backend") }
    fileprivate var connectHealthLabel: String {
        TL(
            pl: "Połącz i zaimportuj", en: "Connect and import", uk: "Підключити й імпортувати",
            ru: "Подключить и импортировать",
            es: "Conectar / importar")
    }
    fileprivate var importingLabel: String {
        TL(pl: "Import…", en: "Importing…", uk: "Імпорт…", ru: "Импорт…", es: "Importando…")
    }
    fileprivate var connectLabel: String {
        TL(pl: "Połącz", en: "Connect", uk: "Підключити", ru: "Подключить", es: "Conectar")
    }
    fileprivate var autoSyncHint: String {
        TL(
            pl: "Autoodświeżanie treningów włączone na ekranie Dziś.",
            en: "Workout auto-sync is on for Today.",
            uk: "Автосинхронізацію тренувань увімкнено на екрані Сьогодні.",
            ru: "Автосинхронизация тренировок включена на главной.",
            es: "La sincronización automática está activa en Hoy.")
    }

    private static func healthMessage(
        weight: HealthImporter.ImportResult?,
        workouts: HealthWorkoutImporter.ImportResult?
    ) -> String {
        if case .unavailable = weight { return unavailableMessage }
        if case .unavailable = workouts { return unavailableMessage }
        if case .denied = weight { return deniedMessage }
        if case .denied = workouts { return deniedMessage }
        if case .failed(let reason) = weight { return reason }
        if case .failed(let reason) = workouts { return reason }

        let weightCount: Int = {
            guard case .imported(let count) = weight else { return 0 }
            return count
        }()
        let workoutCount: Int = {
            guard case .imported(let count) = workouts else { return 0 }
            return count
        }()
        if weightCount + workoutCount == 0 {
            return TL(
                pl: "Połączono. Brak nowych wpisów.",
                en: "Connected. No new entries.",
                uk: "Підключено. Нових записів немає.",
                ru: "Подключено. Новых записей нет.",
                es: "Conectado. No hay entradas nuevas.")
        }
        return String.localizedStringWithFormat(importedMessageFormat, workoutCount, weightCount)
    }

    private static var unavailableMessage: String {
        TL(
            pl: "Apple Health jest niedostępne na tym urządzeniu.",
            en: "Apple Health is unavailable on this device.",
            uk: "Apple Health недоступний на цьому пристрої.",
            ru: "Apple Health недоступен на этом устройстве.",
            es: "Apple Health no está disponible en este dispositivo.")
    }

    private static var deniedMessage: String {
        TL(
            pl: "Dostęp do Apple Health jest wyłączony.",
            en: "Apple Health access is off.",
            uk: "Доступ до Apple Health вимкнено.",
            ru: "Доступ к Apple Health выключен.",
            es: "El acceso a Apple Health está desactivado.")
    }

    private static var importedMessageFormat: String {
        TL(
            pl: "Zaimportowano: %lld treningów, %lld wpisów wagi.",
            en: "Imported: %lld workouts, %lld weight entries.",
            uk: "Імпортовано: %lld тренувань, %lld записів ваги.",
            ru: "Импортировано: %lld тренировок, %lld записей веса.",
            es: "Importado: %lld entrenamientos, %lld registros de peso.")
    }
}
