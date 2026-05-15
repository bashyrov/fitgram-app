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
    let onSignOut: () -> Void
    let onDeleteAccount: () -> Void
    let onRestartOnboarding: () -> Void

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
    @State private var exportError: String?
    @State private var orphanSweepResult: Int?

    @AppStorage("preferences.morningReminderEnabled") private var morningReminderEnabled = true
    @AppStorage("preferences.streakRiskEnabled") private var streakRiskEnabled = true
    @AppStorage("preferences.eveningReminderEnabled") private var eveningReminderEnabled = true

    var body: some View {
        ZStack {
            Tokens.Palette.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: Tokens.Space.lg) {
                    preferencesSection
                    dataSection
                    legalSection
                    accountSection
                    appVersionFooter
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.vertical, Tokens.Space.lg)
            }
        }
        .navigationTitle(Text("Ustawienia"))
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
        .alert("Usunąć konto?", isPresented: $deleteConfirmation) {
            Button("Anuluj", role: .cancel) {}
            Button("Usuń", role: .destructive, action: onDeleteAccount)
        } message: {
            Text("Operacja usuwa wszystkie Twoje dane lokalne i serwerowe. Nie można cofnąć.")
        }
        .alert(
            "Eksport nieudany",
            isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportError ?? "")
        }
    }

    // MARK: - Preferences

    private var preferencesSection: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.xs) {
                sectionHeader("Preferencje", symbol: "slider.horizontal.3", tint: Tokens.Palette.primary)
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
                            Text("Język aplikacji")
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
                    title: "Kalibracja AI",
                    role: nil,
                    action: { isCalibrating = true },
                    tint: Tokens.Palette.primary
                )
                .disabled(user == nil)
                separator
                actionRow(
                    symbol: "calendar",
                    title: "Historia serii",
                    role: nil,
                    action: { isStreakCalendarPresented = true },
                    tint: Tokens.Palette.accent
                )
                separator
                actionRow(
                    symbol: "arrow.counterclockwise",
                    title: "Powtórz onboarding",
                    role: nil,
                    action: { isRestartOnboardingConfirmed = true },
                    tint: Tokens.Palette.inkMuted
                )
            }
        }
        .confirmationDialog(
            "Powtórzyć onboarding?",
            isPresented: $isRestartOnboardingConfirmed,
            titleVisibility: .visible
        ) {
            Button("Powtórz", role: .destructive, action: onRestartOnboarding)
            Button("Anuluj", role: .cancel) {}
        } message: {
            Text("Twoje dane zostaną — przeprowadzimy Cię tylko jeszcze raz przez ustawienia.")
        }
    }

    private var privacyRowTitle: LocalizedStringKey {
        switch privacyStore.current.visibility {
        case .privateOnly: return "Prywatność — wyłączone"
        case .friendsOnly: return "Prywatność — znajomi"
        case .publicLink: return "Prywatność — z linkiem"
        }
    }

    private var preferencesRowTitle: LocalizedStringKey {
        let enabled = [morningReminderEnabled, streakRiskEnabled, eveningReminderEnabled]
            .filter { $0 }
            .count
        if enabled == 3 {
            return "Przypomnienia, język, jednostki"
        }
        if enabled == 0 {
            return "Przypomnienia wyciszone"
        }
        return "Przypomnienia (\(enabled) / 3 aktywne)"
    }

    // MARK: - Data

    private var dataSection: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.xs) {
                sectionHeader("Twoje dane", symbol: "tray.full.fill", tint: Tokens.Palette.accent)
                separator
                actionRow(
                    symbol: "square.and.arrow.up",
                    title: isPreparingExport ? "Przygotowujemy…" : "Pobierz eksport JSON",
                    role: nil,
                    action: { Task { await runExport() } },
                    tint: Tokens.Palette.primary
                )
                .disabled(isPreparingExport || user == nil)
                separator
                actionRow(
                    symbol: "tablecells",
                    title: "Eksport CSV (Excel)",
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
                    title: "Szukaj w historii",
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

    private var photosRowTitle: LocalizedStringKey {
        if let orphanSweepResult {
            return "Usunięto \(orphanSweepResult) zdjęć"
        }
        if let size = photoCacheSize {
            return "Wyczyść osierocone zdjęcia (\(size))"
        }
        return "Wyczyść osierocone zdjęcia"
    }

    private var photoCacheSize: LocalizedStringKey? {
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

    private var bundleRowTitle: LocalizedStringKey {
        isPreparingBundle ? "Pakuję bundle…" : "Pełna paczka (ZIP)"
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
                exportError = String(describing: error)
            }
        }
    }

    private func runCSVExport(from: Date?, to: Date?) {
        do {
            let url = try csvExportService.export(from: from, to: to)
            sharedFile = SharedFile(url: url)
        } catch {
            exportError = String(describing: error)
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
                sectionHeader("Prawo i pomoc", symbol: "doc.text.fill", tint: Tokens.Palette.success)
                separator
                Button {
                    isHelpPresented = true
                } label: {
                    legalRow(symbol: "questionmark.circle.fill", title: "Pomoc / FAQ")
                }
                .buttonStyle(.plain)
                separator
                Button {
                    isLegalPresented = true
                } label: {
                    legalRow(symbol: "lock.shield.fill", title: "Prawo i prywatność")
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Account

    private var accountSection: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.xs) {
                sectionHeader("Konto", symbol: "person.crop.circle.fill", tint: Tokens.Palette.inkMuted)
                separator
                actionRow(
                    symbol: "rectangle.portrait.and.arrow.right",
                    title: "Wyloguj",
                    role: .destructive,
                    action: onSignOut
                )
                separator
                actionRow(
                    symbol: "trash.fill",
                    title: "Usuń konto",
                    role: .destructive,
                    action: { deleteConfirmation = true }
                )
            }
        }
    }

    // MARK: - Footer

    private var appVersionFooter: some View {
        VStack(spacing: 2) {
            Text("Mealgram \(Self.appVersionString)")
                .font(Tokens.Font.footnote)
                .foregroundStyle(Tokens.Palette.inkSubtle)
            Text("Zrobione z miłością w Polsce")
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

    // MARK: - Helpers

    private var separator: some View {
        Rectangle()
            .fill(Tokens.Palette.separator)
            .frame(height: 0.5)
            .padding(.leading, 48)
    }

    private func sectionHeader(
        _ text: LocalizedStringKey,
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
        title: LocalizedStringKey,
        role: ButtonRole?,
        action: @escaping () -> Void,
        tint: Color? = nil,
        subtitle: LocalizedStringKey? = nil
    ) -> some View {
        let resolvedTint = role == .destructive
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

    private func legalRow(symbol: String, title: LocalizedStringKey) -> some View {
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
