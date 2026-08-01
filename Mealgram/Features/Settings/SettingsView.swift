import SwiftUI

// swiftlint:disable type_body_length file_length

/// Dedicated Settings hub raised from Profile. Holds everything that
/// used to live inline on Profile but is "infrequent" — reminders,
/// privacy, AI calibration, streak history, onboarding replay, data
/// export, legal pages, and account actions.
///
/// Profile keeps the "everyday" surfaces (goals, stats, achievements,
/// heatmap) so the Profile screen reads as identity-and-progress and
/// this screen reads as preferences-and-data.
struct SettingsView: View {
    let user: User?
    let streak: Streak?
    let exportService: DataExportService
    let csvExportService: MealCSVExportService
    let bundleExportService: DataBundleExportService
    let mealSearchService: MealSearchService
    let mealRepository: MealRepository
    let photoStore: MealPhotoStore?
    let streakCalendarService: StreakCalendarService
    let calibrationService: CalibrationService
    let privacyStore: PrivacyStore
    var weightService: WeightService?
    let onSignOut: () -> Void
    let onDeleteAccount: () async throws -> Void
    let onRestartOnboarding: () throws -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(LocalizationStore.self) private var localizationStore

    private var activeLanguageLabel: String {
        let code = localizationStore.locale.identifier
        let primary = String(code.prefix(2))
        return LocalizationStore.supportedLanguages
            .first(where: { $0.code == primary })
            .map { "\($0.flag)  \($0.nativeName)" } ?? primary.uppercased()
    }

    @State private var sharedFile: SharedFile?
    @State private var isPreparingExport = false
    @State private var isCSVRangePresented = false
    @State private var isPreparingBundle = false
    @State private var isEditingPreferences = false
    @State private var isPrivacyPresented = false
    @State private var isCalibrating = false
    @State private var isStreakCalendarPresented = false
    @State private var isRestartOnboardingConfirmed = false
    @State private var isSearchPresented = false
    @State private var searchSelectedMeal: MealEntry?
    @State private var isHelpPresented = false
    @State private var isLegalPresented = false
    @State private var deleteConfirmation = false
    @State private var isDeletingAccount = false
    @State private var exportError: String?
    @State private var accountActionError: String?
    @State private var orphanSweepResult: Int?
    @State private var isImportingHealth = false
    @State private var healthImportStatus: String?

    @AppStorage("preferences.morningReminderEnabled") private var morningReminderEnabled = true
    @AppStorage("preferences.streakRiskEnabled") private var streakRiskEnabled = true
    @AppStorage("preferences.eveningReminderEnabled") private var eveningReminderEnabled = true

    var body: some View {
        ZStack {
            settingsBackground
            ScrollView {
                VStack(spacing: Tokens.Space.lg) {
                    preferencesSection
                    integrationsSection
                    dataSection
                    legalSection
                    accountSection
                    appVersionFooter
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.vertical, Tokens.Space.lg)
            }
        }
        .navigationTitle(Text(settingsTitle))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isPrivacyPresented) {
            PrivacySettingsSheet(store: privacyStore) { isPrivacyPresented = false }
        }
        .sheet(isPresented: $isEditingPreferences) {
            if let user {
                PreferencesView(user: user) { isEditingPreferences = false }
            }
        }
        .sheet(isPresented: $isCalibrating) {
            if let user {
                CalibrationView(
                    userRemoteID: user.remoteID,
                    service: calibrationService,
                    onDismiss: { isCalibrating = false }
                )
            }
        }
        .sheet(isPresented: $isStreakCalendarPresented) {
            StreakCalendarSheet(
                service: streakCalendarService,
                onDismiss: { isStreakCalendarPresented = false }
            )
        }
        .sheet(item: $sharedFile) { file in
            ShareSheet(activityItems: [file.url])
        }
        .sheet(isPresented: $isCSVRangePresented) {
            CSVExportRangeSheet(
                onExport: { from, to in
                    isCSVRangePresented = false
                    runCSVExport(from: from, to: to)
                },
                onDismiss: { isCSVRangePresented = false }
            )
        }
        .sheet(isPresented: $isSearchPresented) {
            MealSearchSheet(
                service: mealSearchService,
                onSelect: { meal in
                    isSearchPresented = false
                    searchSelectedMeal = meal
                },
                onDismiss: { isSearchPresented = false }
            )
        }
        .sheet(item: $searchSelectedMeal) { meal in
            MealDetailSheet(
                meal: meal,
                repository: mealRepository,
                photoStore: photoStore,
                onDismiss: { searchSelectedMeal = nil },
                onChanged: {}
            )
        }
        .sheet(isPresented: $isHelpPresented) {
            HelpFAQSheet(onDismiss: { isHelpPresented = false })
        }
        .sheet(isPresented: $isLegalPresented) {
            LegalSheet(onDismiss: { isLegalPresented = false })
        }
        .alert(deleteAccountQuestion, isPresented: $deleteConfirmation) {
            Button(cancelTitle, role: .cancel) {}
            Button(deleteTitle, role: .destructive) {
                Task { await runDeleteAccount() }
            }
        } message: {
            Text(deleteAccountMessage)
        }
        .alert(
            accountActionFailedTitle,
            isPresented: Binding(
                get: { accountActionError != nil },
                set: { if !$0 { accountActionError = nil } }
            )
        ) {
            Button(okTitle, role: .cancel) {}
        } message: {
            Text(accountActionError ?? "")
        }
        .alert(
            exportFailedTitle,
            isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })
        ) {
            Button(okTitle, role: .cancel) {}
        } message: {
            Text(exportError ?? "")
        }
    }

    // MARK: - Preferences

    private var settingsBackground: some View {
        ZStack {
            Tokens.Palette.background
            Circle()
                .fill(Tokens.Palette.primarySoft.opacity(0.42))
                .frame(width: 350, height: 350)
                .blur(radius: 108)
                .offset(x: -160, y: -220)
            Circle()
                .fill(Tokens.Palette.accentSoft.opacity(0.22))
                .frame(width: 310, height: 310)
                .blur(radius: 112)
                .offset(x: 160, y: -20)
            Circle()
                .fill(Tokens.Palette.warning.opacity(0.08))
                .frame(width: 250, height: 250)
                .blur(radius: 100)
                .offset(x: -80, y: 390)
        }
        .ignoresSafeArea()
    }

    private var preferencesSection: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.xs) {
                sectionHeader(preferencesTitle, symbol: "slider.horizontal.3", tint: Tokens.Palette.primary)
                separator
                NavigationLink {
                    LanguageSettingsView(store: localizationStore) {}
                } label: {
                    HStack(spacing: Tokens.Space.md) {
                        ZStack {
                            Circle()
                                .fill(Color(red: 0.55, green: 0.45, blue: 0.85).opacity(0.15))
                                .frame(width: 36, height: 36)
                            Image(systemName: "globe")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color(red: 0.55, green: 0.45, blue: 0.85))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(appLanguageTitle)
                                .font(Tokens.Font.body)
                                .foregroundStyle(Tokens.Palette.ink)
                            Text(activeLanguageLabel)
                                .font(Tokens.Font.caption)
                                .foregroundStyle(Tokens.Palette.inkMuted)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Tokens.Palette.inkSubtle)
                    }
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                separator
                actionRow(
                    symbol: "bell.fill",
                    title: preferencesRowTitle,
                    role: nil,
                    action: { isEditingPreferences = true },
                    tint: Tokens.Palette.warning
                )
                .disabled(user == nil)
                separator
                actionRow(
                    symbol: "lock.shield.fill",
                    title: privacyRowTitle,
                    role: nil,
                    action: { isPrivacyPresented = true },
                    tint: Tokens.Palette.accent
                )
                separator
                actionRow(
                    symbol: "wand.and.stars",
                    title: aiCalibrationTitle,
                    role: nil,
                    action: { isCalibrating = true },
                    tint: Tokens.Palette.primary
                )
                .disabled(user == nil)
                separator
                actionRow(
                    symbol: "calendar",
                    title: streakHistoryTitle,
                    role: nil,
                    action: { isStreakCalendarPresented = true },
                    tint: Tokens.Palette.accent
                )
                separator
                actionRow(
                    symbol: "arrow.counterclockwise",
                    title: restartOnboardingTitle,
                    role: nil,
                    action: { isRestartOnboardingConfirmed = true },
                    tint: Tokens.Palette.inkMuted
                )
            }
        }
        .confirmationDialog(
            repeatOnboardingQuestion,
            isPresented: $isRestartOnboardingConfirmed,
            titleVisibility: .visible
        ) {
            Button(repeatTitle, role: .destructive, action: runRestartOnboarding)
            Button(cancelTitle, role: .cancel) {}
        } message: {
            Text(repeatOnboardingMessage)
        }
    }

    private var privacyRowTitle: String {
        switch privacyStore.current.visibility {
        case .privateOnly: return privacyOffTitle
        case .friendsOnly: return privacyFriendsTitle
        case .publicLink: return privacyLinkTitle
        }
    }

    private var preferencesRowTitle: String {
        let enabled = [morningReminderEnabled, streakRiskEnabled, eveningReminderEnabled]
            .filter { $0 }
            .count
        if enabled == 3 {
            return remindersThemeUnitsTitle
        }
        if enabled == 0 {
            return remindersMutedTitle
        }
        return String.localizedStringWithFormat(remindersActiveFormat, enabled)
    }

    // MARK: - Data

    @ViewBuilder
    private var integrationsSection: some View {
        if weightService != nil, user != nil {
            Card {
                VStack(alignment: .leading, spacing: Tokens.Space.xs) {
                    sectionHeader(
                        integrationsTitle,
                        symbol: "heart.text.square.fill",
                        tint: Tokens.Palette.error
                    )
                    separator
                    actionRow(
                        symbol: "applelogo",
                        title: healthImportRowTitle,
                        role: nil,
                        action: { Task { await runHealthImport() } },
                        tint: Tokens.Palette.error
                    )
                    .disabled(isImportingHealth)
                    Text(
                        appleHealthHint
                    )
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                    .padding(.horizontal, Tokens.Space.md)
                    .padding(.bottom, Tokens.Space.sm)
                }
            }
        }
    }

    private var healthImportRowTitle: String {
        if isImportingHealth { return importingHealthTitle }
        if let healthImportStatus { return healthImportStatus }
        return importWeightHealthTitle
    }

    private func runHealthImport() async {
        guard let weightService, let user, !isImportingHealth else { return }
        isImportingHealth = true
        defer { isImportingHealth = false }
        let importer = HealthImporter(
            health: HealthKitService(),
            weightService: weightService
        )
        let result = await importer.runImport(for: user.remoteID)
        healthImportStatus = Self.healthMessage(for: result)
        Haptics.light()
        Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            healthImportStatus = nil
        }
    }

    private static func healthMessage(for result: HealthImporter.ImportResult) -> String {
        switch result {
        case .unavailable:
            return TL(
                pl: "Apple Health jest niedostępne na tym urządzeniu",
                en: "Apple Health is unavailable on this device",
                uk: "Apple Health недоступний на цьому пристрої",
                ru: "Apple Health недоступен на этом устройстве",
                es: "Apple Health no está disponible en este dispositivo"
            )
        case .denied:
            return TL(
                pl: "Brak zgody — możesz włączyć w Ustawieniach iOS",
                en: "No permission — you can enable it in iOS Settings",
                uk: "Немає дозволу — його можна ввімкнути в налаштуваннях iOS",
                ru: "Нет разрешения — его можно включить в настройках iOS",
                es: "Sin permiso — puedes activarlo en Ajustes de iOS"
            )
        case .imported(let count):
            return String.localizedStringWithFormat(
                TL(
                    pl: "Zaimportowano %lld wpisów",
                    en: "Imported %lld entries",
                    uk: "Імпортовано %lld записів",
                    ru: "Импортировано %lld записей",
                    es: "Se importaron %lld entradas"
                ),
                count
            )
        case .noNewSamples:
            return TL(
                pl: "Brak nowych wpisów",
                en: "No new entries",
                uk: "Немає нових записів",
                ru: "Нет новых записей",
                es: "No hay entradas nuevas"
            )
        case .failed:
            return TL(
                pl: "Spróbuj ponownie za chwilę",
                en: "Try again in a moment",
                uk: "Спробуйте ще раз трохи пізніше",
                ru: "Попробуйте еще раз чуть позже",
                es: "Inténtalo de nuevo en un momento"
            )
        }
    }

    private var dataSection: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.xs) {
                sectionHeader(yourDataTitle, symbol: "tray.full.fill", tint: Tokens.Palette.accent)
                separator
                actionRow(
                    symbol: "square.and.arrow.up",
                    title: isPreparingExport ? preparingTitle : jsonExportTitle,
                    role: nil,
                    action: { Task { await runExport() } },
                    tint: Tokens.Palette.primary
                )
                .disabled(isPreparingExport || user == nil)
                separator
                actionRow(
                    symbol: "tablecells",
                    title: csvExportTitle,
                    role: nil,
                    action: { isCSVRangePresented = true },
                    tint: Tokens.Palette.success
                )
                separator
                actionRow(
                    symbol: "archivebox.fill",
                    title: bundleRowTitle,
                    role: nil,
                    action: { runBundleExport() },
                    tint: Tokens.Palette.warning
                )
                .disabled(isPreparingBundle || user == nil)
                separator
                actionRow(
                    symbol: "magnifyingglass",
                    title: searchHistoryTitle,
                    role: nil,
                    action: { isSearchPresented = true },
                    tint: Tokens.Palette.accent
                )
                if photoStore != nil {
                    separator
                    actionRow(
                        symbol: "photo.stack.fill",
                        title: photosRowTitle,
                        role: nil,
                        action: { runOrphanPhotoSweep() },
                        tint: Tokens.Palette.inkMuted
                    )
                }
            }
        }
    }

    private var photosRowTitle: String {
        if let orphanSweepResult {
            return String.localizedStringWithFormat(removedPhotosFormat, orphanSweepResult)
        }
        if let size = photoCacheSize {
            return String.localizedStringWithFormat(cleanPhotosWithSizeFormat, String(describing: size))
        }
        return cleanPhotosTitle
    }

    private var photoCacheSize: String? {
        guard let store = photoStore else { return nil }
        let bytes = store.totalBytesOnDisk()
        guard bytes > 0 else { return nil }
        let mb = Double(bytes) / (1024 * 1024)
        if mb < 1 {
            let kb = Double(bytes) / 1024
            return "\(Int(kb.rounded())) KB"
        }
        return "\(String(format: "%.1f", mb)) MB"
    }

    private var bundleRowTitle: String {
        isPreparingBundle ? bundlingTitle : fullBundleTitle
    }

    private func runOrphanPhotoSweep() {
        guard let photoStore else { return }
        let removed = mealRepository.cleanupOrphanedPhotos(in: photoStore)
        orphanSweepResult = removed
        Haptics.light()
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            orphanSweepResult = nil
        }
    }

    private func runBundleExport() {
        guard let user, !isPreparingBundle else { return }
        isPreparingBundle = true
        Task { @MainActor in
            defer { isPreparingBundle = false }
            do {
                let url = try bundleExportService.export(forUser: user.remoteID)
                sharedFile = SharedFile(url: url)
            } catch {
                exportError = String.localizedStringWithFormat(L("Export failed: %@"), String(describing: error))
            }
        }
    }

    private func runCSVExport(from: Date?, to: Date?) {
        do {
            let url = try csvExportService.export(from: from, to: to)
            sharedFile = SharedFile(url: url)
        } catch {
            exportError = String.localizedStringWithFormat(L("Export failed: %@"), String(describing: error))
        }
    }

    private func runExport() async {
        guard let user, !isPreparingExport else { return }
        isPreparingExport = true
        defer { isPreparingExport = false }
        do {
            let url = try exportService.export(for: user.remoteID)
            sharedFile = SharedFile(url: url)
        } catch {
            exportError = error.localizedDescription
        }
    }

    // MARK: - Legal

    private var legalSection: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.xs) {
                sectionHeader(legalHelpTitle, symbol: "doc.text.fill", tint: Tokens.Palette.success)
                separator
                Button {
                    isHelpPresented = true
                } label: {
                    legalRow(symbol: "questionmark.circle.fill", title: helpFAQTitle)
                }
                .buttonStyle(.plain)
                separator
                Button {
                    isLegalPresented = true
                } label: {
                    legalRow(symbol: "lock.shield.fill", title: legalPrivacyTitle)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Account

    private var accountSection: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.xs) {
                sectionHeader(accountTitle, symbol: "person.crop.circle.fill", tint: Tokens.Palette.inkMuted)
                separator
                actionRow(
                    symbol: "rectangle.portrait.and.arrow.right",
                    title: signOutTitle,
                    role: .destructive,
                    action: onSignOut
                )
                separator
                actionRow(
                    symbol: "trash.fill",
                    title: isDeletingAccount ? deletingAccountTitle : deleteAccountTitle,
                    role: .destructive,
                    action: { deleteConfirmation = true }
                )
                .disabled(isDeletingAccount)
            }
        }
    }

    private func runDeleteAccount() async {
        guard !isDeletingAccount else { return }
        isDeletingAccount = true
        defer { isDeletingAccount = false }
        do {
            try await onDeleteAccount()
        } catch {
            accountActionError = deleteAccountFailedMessage
        }
    }

    private func runRestartOnboarding() {
        do {
            try onRestartOnboarding()
        } catch {
            accountActionError = restartOnboardingFailedMessage
        }
    }

    // MARK: - Footer

    private var appVersionFooter: some View {
        VStack(spacing: 2) {
            Text(String.localizedStringWithFormat(L("Mealgram %@"), Self.appVersionString))
                .font(Tokens.Font.footnote)
                .foregroundStyle(Tokens.Palette.inkSubtle)
            Text(madeInPolandTitle)
                .font(Tokens.Font.footnote)
                .foregroundStyle(Tokens.Palette.inkSubtle)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Tokens.Space.sm)
    }

    private static var appVersionString: String {
        let info = Bundle.main.infoDictionary
        let short = (info?["CFBundleShortVersionString"] as? String) ?? "0"
        let build = (info?["CFBundleVersion"] as? String) ?? "0"
        return "v\(short) (\(build))"
    }

    // MARK: - Localized Copy

    private var settingsTitle: String {
        TL(pl: "Ustawienia", en: "Settings", uk: "Налаштування", ru: "Настройки", es: "Ajustes")
    }

    private var preferencesTitle: String {
        TL(pl: "Preferencje", en: "Preferences", uk: "Параметри", ru: "Параметры", es: "Preferencias")
    }

    private var appLanguageTitle: String {
        TL(
            pl: "Język aplikacji", en: "App language", uk: "Мова застосунку", ru: "Язык приложения",
            es: "Idioma de la app")
    }

    private var aiCalibrationTitle: String {
        TL(
            pl: "Kalibracja AI", en: "AI calibration", uk: "Калібрування AI", ru: "Калибровка AI",
            es: "Calibración de AI")
    }

    private var streakHistoryTitle: String {
        TL(
            pl: "Historia serii", en: "Streak history", uk: "Історія серії", ru: "История серии",
            es: "Historial de racha")
    }

    private var restartOnboardingTitle: String {
        TL(
            pl: "Powtórz onboarding", en: "Replay onboarding", uk: "Повторити онбординг", ru: "Повторить онбординг",
            es: "Repetir introducción")
    }

    private var remindersThemeUnitsTitle: String {
        TL(
            pl: "Przypomnienia, motyw, jednostki",
            en: "Reminders, theme, units",
            uk: "Нагадування, тема, одиниці",
            ru: "Напоминания, тема, единицы",
            es: "Recordatorios, tema, unidades"
        )
    }

    private var remindersMutedTitle: String {
        TL(
            pl: "Przypomnienia wyciszone", en: "Reminders muted", uk: "Нагадування вимкнено",
            ru: "Напоминания выключены", es: "Recordatorios silenciados")
    }

    private var remindersActiveFormat: String {
        TL(
            pl: "Przypomnienia (%lld / 3 aktywne)",
            en: "Reminders (%lld / 3 active)",
            uk: "Нагадування (%lld / 3 активні)",
            ru: "Напоминания (%lld / 3 активны)",
            es: "Recordatorios (%lld / 3 activos)"
        )
    }

    private var privacyOffTitle: String {
        TL(
            pl: "Prywatność — wyłączone", en: "Privacy — off", uk: "Приватність — вимкнено",
            ru: "Приватность — выключено", es: "Privacidad — desactivada")
    }

    private var privacyFriendsTitle: String {
        TL(
            pl: "Prywatność — znajomi", en: "Privacy — friends", uk: "Приватність — друзі", ru: "Приватность — друзья",
            es: "Privacidad — amigos")
    }

    private var privacyLinkTitle: String {
        TL(
            pl: "Prywatność — z linkiem", en: "Privacy — with link", uk: "Приватність — за посиланням",
            ru: "Приватность — по ссылке", es: "Privacidad — con enlace")
    }

    private var integrationsTitle: String {
        TL(pl: "Integracje", en: "Integrations", uk: "Інтеграції", ru: "Интеграции", es: "Integraciones")
    }

    private var importWeightHealthTitle: String {
        TL(
            pl: "Importuj wagę z Apple Health", en: "Import weight from Apple Health",
            uk: "Імпортувати вагу з Apple Health", ru: "Импортировать вес из Apple Health",
            es: "Importar peso de Apple Health")
    }

    private var importingHealthTitle: String {
        TL(
            pl: "Import z Apple Health…", en: "Importing from Apple Health…", uk: "Імпорт з Apple Health…",
            ru: "Импорт из Apple Health…", es: "Importando desde Apple Health…")
    }

    private var appleHealthHint: String {
        TL(
            pl: "Importujemy tylko wagę z Apple Health. O zgodę poprosimy dopiero po stuknięciu przycisku.",
            en: "We only import weight from Apple Health. Permission is requested only when you tap the button.",
            uk: "Ми імпортуємо з Apple Health лише вагу. Дозвіл запитується тільки після натискання кнопки.",
            ru: "Мы импортируем из Apple Health только вес. Разрешение запрашивается только после нажатия кнопки.",
            es: "Solo importamos el peso desde Apple Health. El permiso se solicita solo al tocar el botón."
        )
    }

    private var yourDataTitle: String {
        TL(pl: "Twoje dane", en: "Your data", uk: "Ваші дані", ru: "Ваши данные", es: "Tus datos")
    }

    private var preparingTitle: String {
        TL(pl: "Przygotowywanie…", en: "Preparing…", uk: "Підготовка…", ru: "Подготовка…", es: "Preparando…")
    }

    private var jsonExportTitle: String {
        TL(
            pl: "Pobierz eksport JSON", en: "Download JSON export", uk: "Завантажити експорт JSON",
            ru: "Скачать экспорт JSON", es: "Descargar exportación JSON")
    }

    private var csvExportTitle: String {
        TL(
            pl: "Eksport CSV (Excel)", en: "Export CSV (Excel)", uk: "Експорт CSV (Excel)", ru: "Экспорт CSV (Excel)",
            es: "Exportar CSV (Excel)")
    }

    private var searchHistoryTitle: String {
        TL(
            pl: "Szukaj w historii", en: "Search history", uk: "Пошук в історії", ru: "Поиск в истории",
            es: "Buscar en el historial")
    }

    private var fullBundleTitle: String {
        TL(
            pl: "Pełny pakiet (ZIP)", en: "Full bundle (ZIP)", uk: "Повний пакет (ZIP)", ru: "Полный пакет (ZIP)",
            es: "Paquete completo (ZIP)")
    }

    private var bundlingTitle: String {
        TL(pl: "Pakowanie…", en: "Bundling…", uk: "Пакування…", ru: "Упаковка…", es: "Empaquetando…")
    }

    private var cleanPhotosTitle: String {
        TL(
            pl: "Wyczyść osierocone zdjęcia", en: "Clean orphan photos", uk: "Очистити зайві фото",
            ru: "Очистить лишние фото", es: "Limpiar fotos huérfanas")
    }

    private var cleanPhotosWithSizeFormat: String {
        TL(
            pl: "Wyczyść osierocone zdjęcia (%@)", en: "Clean orphan photos (%@)", uk: "Очистити зайві фото (%@)",
            ru: "Очистить лишние фото (%@)", es: "Limpiar fotos huérfanas (%@)")
    }

    private var removedPhotosFormat: String {
        TL(
            pl: "Usunięto %lld zdjęć", en: "Removed %lld photos", uk: "Видалено %lld фото", ru: "Удалено %lld фото",
            es: "Se eliminaron %lld fotos")
    }

    private var legalHelpTitle: String {
        TL(pl: "Prawo i pomoc", en: "Legal and help", uk: "Право і допомога", ru: "Право и помощь", es: "Legal y ayuda")
    }

    private var helpFAQTitle: String {
        TL(pl: "Pomoc / FAQ", en: "Help / FAQ", uk: "Допомога / FAQ", ru: "Помощь / FAQ", es: "Ayuda / FAQ")
    }

    private var legalPrivacyTitle: String {
        TL(
            pl: "Prawo i prywatność", en: "Legal and privacy", uk: "Право і приватність", ru: "Право и приватность",
            es: "Legal y privacidad")
    }

    private var accountTitle: String {
        TL(pl: "Konto", en: "Account", uk: "Акаунт", ru: "Аккаунт", es: "Cuenta")
    }

    private var signOutTitle: String {
        TL(pl: "Wyloguj", en: "Sign out", uk: "Вийти", ru: "Выйти", es: "Cerrar sesión")
    }

    private var deleteAccountTitle: String {
        TL(pl: "Usuń konto", en: "Delete account", uk: "Видалити акаунт", ru: "Удалить аккаунт", es: "Eliminar cuenta")
    }

    private var deletingAccountTitle: String {
        TL(
            pl: "Usuwanie konta…",
            en: "Deleting account…",
            uk: "Видалення акаунта…",
            ru: "Удаляем аккаунт…",
            es: "Eliminando cuenta…"
        )
    }

    private var accountActionFailedTitle: String {
        TL(
            pl: "Nie udało się wykonać akcji",
            en: "Action failed",
            uk: "Не вдалося виконати дію",
            ru: "Не удалось выполнить действие",
            es: "No se pudo completar la acción"
        )
    }

    private var deleteAccountFailedMessage: String {
        TL(
            pl: "Nie usunęliśmy konta. Sprawdź połączenie i spróbuj ponownie.",
            en: "We did not delete the account. Check your connection and try again.",
            uk: "Ми не видалили акаунт. Перевірте з'єднання й спробуйте ще раз.",
            ru: "Мы не удалили аккаунт. Проверьте соединение и попробуйте ещё раз.",
            es: "No eliminamos la cuenta. Revisa la conexión e inténtalo de nuevo."
        )
    }

    private var restartOnboardingFailedMessage: String {
        TL(
            pl: "Nie udało się ponownie uruchomić onboardingu. Spróbuj jeszcze raz.",
            en: "We could not restart onboarding. Try again.",
            uk: "Не вдалося перезапустити онбординг. Спробуйте ще раз.",
            ru: "Не удалось перезапустить онбординг. Попробуйте ещё раз.",
            es: "No pudimos reiniciar la introducción. Inténtalo de nuevo."
        )
    }

    private var madeInPolandTitle: String {
        TL(
            pl: "Zrobione z miłością w Polsce", en: "Made with care in Poland", uk: "Створено з турботою в Польщі",
            ru: "Сделано с заботой в Польше", es: "Hecho con cariño en Polonia")
    }

    private var cancelTitle: String {
        TL(pl: "Anuluj", en: "Cancel", uk: "Скасувати", ru: "Отмена", es: "Cancelar")
    }

    private var okTitle: String {
        TL(pl: "OK", en: "OK", uk: "OK", ru: "OK", es: "OK")
    }

    private var deleteTitle: String {
        TL(pl: "Usuń", en: "Delete", uk: "Видалити", ru: "Удалить", es: "Eliminar")
    }

    private var repeatTitle: String {
        TL(pl: "Powtórz", en: "Replay", uk: "Повторити", ru: "Повторить", es: "Repetir")
    }

    private var deleteAccountQuestion: String {
        TL(
            pl: "Usunąć konto?", en: "Delete account?", uk: "Видалити акаунт?", ru: "Удалить аккаунт?",
            es: "¿Eliminar cuenta?")
    }

    private var deleteAccountMessage: String {
        TL(
            pl: "Operacja usuwa wszystkie Twoje dane lokalne i serwerowe. Nie można cofnąć.",
            en: "This removes all your local and server data. It cannot be undone.",
            uk: "Ця дія видалить усі локальні та серверні дані. Її не можна скасувати.",
            ru: "Это удалит все ваши локальные и серверные данные. Действие нельзя отменить.",
            es: "Esto elimina todos tus datos locales y del servidor. No se puede deshacer."
        )
    }

    private var repeatOnboardingQuestion: String {
        TL(
            pl: "Powtórzyć onboarding?", en: "Replay onboarding?", uk: "Повторити онбординг?",
            ru: "Повторить онбординг?", es: "¿Repetir introducción?")
    }

    private var repeatOnboardingMessage: String {
        TL(
            pl: "Twoje dane zostaną — przeprowadzimy Cię tylko jeszcze raz przez ustawienia.",
            en: "Your data stays. We will only guide you through setup again.",
            uk: "Ваші дані залишаться. Ми лише ще раз проведемо вас через налаштування.",
            ru: "Ваши данные останутся. Мы только снова проведем вас через настройки.",
            es: "Tus datos se conservan. Solo te guiaremos de nuevo por la configuración."
        )
    }

    private var exportFailedTitle: String {
        TL(
            pl: "Eksport nieudany", en: "Export failed", uk: "Експорт не вдався", ru: "Экспорт не удался",
            es: "Error al exportar")
    }

    // MARK: - Helpers

    private var separator: some View {
        Rectangle()
            .fill(Tokens.Palette.separator)
            .frame(height: 0.5)
            .padding(.leading, 48)
    }

    private func sectionHeader(
        _ text: String,
        symbol: String? = nil,
        tint: Color = Tokens.Palette.primary
    ) -> some View {
        HStack(spacing: Tokens.Space.sm) {
            if let symbol {
                ZStack {
                    Circle()
                        .fill(tint.opacity(0.18))
                        .frame(width: 28, height: 28)
                    Image(systemName: symbol)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(tint)
                }
            }
            Text(text)
                .font(Tokens.Font.headline)
                .foregroundStyle(Tokens.Palette.ink)
            Spacer()
        }
        .padding(.bottom, 2)
    }

    private func actionRow(
        symbol: String,
        title: String,
        role: ButtonRole?,
        action: @escaping () -> Void,
        tint: Color? = nil,
        subtitle: String? = nil
    ) -> some View {
        let resolvedTint =
            role == .destructive
            ? Tokens.Palette.error
            : (tint ?? Tokens.Palette.primary)
        return Button(role: role, action: action) {
            HStack(spacing: Tokens.Space.md) {
                ZStack {
                    Circle()
                        .fill(resolvedTint.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: symbol)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(resolvedTint)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Tokens.Font.body)
                        .foregroundStyle(role == .destructive ? Tokens.Palette.error : Tokens.Palette.ink)
                    if let subtitle {
                        Text(subtitle)
                            .font(Tokens.Font.caption)
                            .foregroundStyle(Tokens.Palette.inkMuted)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Tokens.Palette.inkSubtle)
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }

    private func legalRow(symbol: String, title: String) -> some View {
        HStack(spacing: Tokens.Space.md) {
            ZStack {
                Circle()
                    .fill(Tokens.Palette.primary.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Tokens.Palette.primary)
            }
            Text(title)
                .font(Tokens.Font.body)
                .foregroundStyle(Tokens.Palette.ink)
            Spacer()
            Image(systemName: "arrow.up.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Tokens.Palette.inkSubtle)
        }
        .padding(.vertical, 6)
    }
}
// swiftlint:enable type_body_length file_length
