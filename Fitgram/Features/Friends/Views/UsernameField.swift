import SwiftUI

/// "@username" input with live format + availability checks. Used in
/// onboarding and in the one-time picker for accounts created earlier.
struct UsernameField: View {
    @Binding var username: String
    @Binding var status: Status
    let socialProfile: any SocialProfileServing
    /// Already chosen on another device — shown read-only.
    var lockedUsername: String?

    enum Status: Equatable {
        case idle
        case checking
        case available
        case taken
        case invalid(String)
        case locked

        var isReady: Bool { self == .available || self == .locked }
    }

    @State private var checkTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            MonoField(label: TL(pl: "Username", en: "Username", uk: "Username", ru: "Username", es: "Usuario")) {
                HStack(spacing: 2) {
                    Text(verbatim: "@")
                        .font(Tokens.Font.manrope(15, weight: 800))
                        .foregroundStyle(Tokens.Mono.muted)
                    TextField("anna.kowalska", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.asciiCapable)
                        .textContentType(.username)
                        .disabled(lockedUsername != nil)
                    Spacer(minLength: 0)
                    statusIcon
                }
            }
            Text(statusText)
                .font(Tokens.Font.manrope(12, weight: 700))
                .foregroundStyle(statusColor)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 6)
        }
        .onAppear {
            if let lockedUsername {
                username = lockedUsername
                status = .locked
            } else if !username.isEmpty {
                scheduleCheck(username)
            }
        }
        .onChange(of: username) { _, value in
            // Never rewrite the text while typing — it drops keystrokes.
            // Checks (and the claim) use the normalised form.
            guard lockedUsername == nil else { return }
            scheduleCheck(UsernamePolicy.normalize(value))
        }
        .onChange(of: lockedUsername) { _, locked in
            guard let locked else { return }
            checkTask?.cancel()
            username = locked
            status = .locked
        }
        .onDisappear { checkTask?.cancel() }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch status {
        case .checking:
            ProgressView().controlSize(.small)
        case .available, .locked:
            Image(systemName: status == .locked ? "lock.fill" : "checkmark.circle.fill")
                .foregroundStyle(Tokens.Mono.strong)
        case .taken, .invalid:
            Image(systemName: "xmark.circle.fill").foregroundStyle(Tokens.Mono.danger)
        case .idle:
            EmptyView()
        }
    }

    private var statusText: String {
        switch status {
        case .idle, .checking:
            return TL(
                pl: "Litery a–z, cyfry, „.” i „_”. Nie da się go później zmienić.",
                en: "Letters a–z, digits, \".\" and \"_\". It can't be changed later.",
                uk: "Літери a–z, цифри, «.» і «_». Змінити потім не можна.",
                ru: "Буквы a–z, цифры, «.» и «_». Потом изменить нельзя.",
                es: "Letras a–z, números, \".\" y \"_\". No se podrá cambiar después.")
        case .available:
            return TL(
                pl: "Wolny! Pamiętaj — tego nie zmienisz później.",
                en: "Available! Remember, you can't change it later.",
                uk: "Вільний! Пам'ятай — змінити потім не вийде.", ru: "Свободен! Помни — потом не изменить.",
                es: "¡Disponible! Recuerda que no podrás cambiarlo.")
        case .taken:
            return TL(
                pl: "Ten username jest już zajęty.", en: "This username is already taken.",
                uk: "Цей username вже зайнятий.",
                ru: "Этот username уже занят.", es: "Ese nombre de usuario ya está en uso.")
        case .invalid(let message):
            return message
        case .locked:
            return TL(
                pl: "Twój username jest już ustawiony i nie można go zmienić.",
                en: "Your username is already set and can't be changed.",
                uk: "Твій username вже встановлено, його не можна змінити.",
                ru: "Твой username уже установлен, его нельзя изменить.",
                es: "Tu nombre de usuario ya está definido y no se puede cambiar.")
        }
    }

    private var statusColor: Color {
        switch status {
        case .taken, .invalid: return Tokens.Mono.danger
        default: return Tokens.Mono.muted
        }
    }

    private func scheduleCheck(_ value: String) {
        checkTask?.cancel()
        if value.isEmpty {
            status = .idle
            return
        }
        if let problem = UsernamePolicy.problem(for: value) {
            status = .invalid(problem.message)
            return
        }
        status = .checking
        let service = socialProfile
        checkTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            let available = (try? await service.isUsernameAvailable(value)) ?? true
            guard !Task.isCancelled, UsernamePolicy.normalize(username) == value else { return }
            status = available ? .available : .taken
        }
    }
}

/// One-time username picker for accounts that existed before usernames.
struct UsernamePickerSheet: View {
    @Bindable var state: FriendsState
    let suggestion: String
    let onDone: (String) -> Void
    let onDismiss: () -> Void

    @State private var username = ""
    @State private var status: UsernameField.Status = .idle
    @State private var isSaving = false
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    MonoH1(
                        text: TL(
                            pl: "Wybierz username", en: "Pick a username", uk: "Обери username", ru: "Выбери username",
                            es: "Elige tu usuario"),
                        sub: TL(
                            pl:
                                "Po nim znajomi znajdą Cię w wyszukiwarce. Wybierasz go raz — potem nie da się go zmienić.",
                            en: "Friends will find you by it. You pick it once — it can't be changed later.",
                            uk: "За ним друзі знайдуть тебе в пошуку. Обираєш один раз — змінити потім не можна.",
                            ru: "По нему друзья найдут тебя в поиске. Выбираешь один раз — потом не изменить.",
                            es: "Tus amigos te encontrarán por él. Lo eliges una vez y no se puede cambiar.")
                    )
                    UsernameField(username: $username, status: $status, socialProfile: state.socialProfile)
                        .monoCard(padding: 16)
                    if let errorText {
                        Text(errorText)
                            .font(Tokens.Font.manrope(12, weight: 700))
                            .foregroundStyle(Tokens.Mono.danger)
                            .padding(.horizontal, 6)
                    }
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.vertical, 12)
            }
            .background(Tokens.Palette.background.ignoresSafeArea())
            .monoNavigationTitle(TL(pl: "Username", en: "Username", uk: "Username", ru: "Username", es: "Usuario"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    MonoNavIcon(systemName: "xmark", accessibilityLabel: L("Zamknij"), action: onDismiss)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    MonoNavPill(title: L("Save")) {
                        Task { await save() }
                    }
                    .disabled(status != .available || isSaving)
                    .opacity(status == .available && !isSaving ? 1 : 0.45)
                }
            }
            .onAppear {
                if username.isEmpty { username = suggestion }
            }
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        do {
            try await state.claimUsername(username)
            Haptics.success()
            onDone(UsernamePolicy.normalize(username))
        } catch UsernameClaimError.taken {
            status = .taken
        } catch {
            errorText = TL(
                pl: "Nie udało się zapisać. Spróbuj za chwilę.", en: "Couldn't save. Try again in a moment.",
                uk: "Не вдалося зберегти. Спробуй за хвилину.", ru: "Не удалось сохранить. Попробуй чуть позже.",
                es: "No se pudo guardar. Inténtalo en un momento.")
        }
    }
}
