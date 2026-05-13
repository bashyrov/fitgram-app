import SwiftUI

/// Routes the voice-capture stages: permission gate → idle → listening
/// → finished/confirm → save. AI parsing of the transcript (Claude via
/// Worker) slots in here once the Worker has credentials.
struct VoiceRootView: View {
    @State private var state: VoiceFlowState
    let parser: VoiceMealParser
    let onDismiss: () -> Void

    init(
        session: VoiceCaptureSession = VoiceCaptureSession(),
        mealSaver: any MealSaving,
        parser: VoiceMealParser = VoiceMealParser(),
        onDismiss: @escaping () -> Void
    ) {
        self.parser = parser
        self._state = State(
            initialValue: VoiceFlowState(session: session, mealSaver: mealSaver, parser: parser)
        )
        self.onDismiss = onDismiss
    }

    var body: some View {
        ZStack {
            Tokens.Palette.background.ignoresSafeArea()
            switch state.stage {
            case .checkingPermission:
                ProgressView()
                    .tint(Tokens.Palette.primary)
            case .needsPermission(let status):
                VoicePermissionGate(
                    status: status,
                    onRetry: { Task { await state.start() } },
                    onDismiss: onDismiss
                )
            case .idle, .listening:
                VStack {
                    topBar
                    Spacer(minLength: 0)
                    VoiceCaptureView(
                        isListening: isListening,
                        transcript: state.partialTranscript,
                        onToggle: toggleCapture
                    )
                    Spacer(minLength: 0)
                }
            case .finished(let transcript):
                ConfirmationView(
                    transcript: transcript,
                    parser: parser,
                    onSave: { commit($0) },
                    onRetake: { state.reset() },
                    onDismiss: onDismiss
                )
            case .error(let message):
                VStack(spacing: Tokens.Space.xl) {
                    Spacer()
                    EmptyState(
                        symbol: "exclamationmark.triangle.fill",
                        title: "Coś nie zadziałało",
                        message: LocalizedStringKey(message),
                        action: .init(title: "Spróbuj ponownie", perform: { Task { await state.start() } })
                    )
                    Spacer()
                    SecondaryButton(title: "Zamknij", systemImage: "xmark", action: onDismiss)
                        .padding(.horizontal, Tokens.Space.screenPadding)
                        .padding(.bottom, Tokens.Space.xl)
                }
            }
        }
        .animation(Tokens.Motion.gentle, value: stageKey)
        .task { await state.start() }
        .onDisappear { state.reset() }
    }

    // MARK: - Subviews

    private var topBar: some View {
        HStack {
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Tokens.Palette.inkMuted)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Tokens.Palette.surfaceMuted))
            }
            .padding(.leading, Tokens.Space.screenPadding)
            .padding(.top, Tokens.Space.md)
            .accessibilityLabel(Text("Zamknij"))
            Spacer()
        }
    }

    private var isListening: Bool {
        if case .listening = state.stage { return true }
        return false
    }

    private var stageKey: String {
        switch state.stage {
        case .checkingPermission: return "checking"
        case .needsPermission: return "permission"
        case .idle: return "idle"
        case .listening: return "listening"
        case .finished: return "finished"
        case .error: return "error"
        }
    }

    private func toggleCapture() {
        switch state.stage {
        case .idle:
            state.beginListening()
        case .listening:
            state.stopListening()
        default:
            break
        }
    }

    private func commit(_ transcript: String) {
        try? state.commit(transcript: transcript)
        onDismiss()
    }
}

private struct VoicePermissionGate: View {
    let status: VoicePermission.Status
    let onRetry: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: Tokens.Space.xl) {
            Spacer()
            EmptyState(
                symbol: "mic.slash.fill",
                title: "Potrzebujemy mikrofonu",
                message: status == .denied
                    ? "Włącz mikrofon + rozpoznawanie mowy w Ustawieniach, żeby dyktować posiłki."
                    : "Pozwól na mikrofon i rozpoznawanie mowy, żeby dyktować posiłki.",
                action: status == .denied
                    ? .init(title: "Otwórz Ustawienia", perform: openSettings)
                    : .init(title: "Pozwól", perform: onRetry)
            )
            Spacer()
            SecondaryButton(title: "Zamknij", systemImage: "xmark", action: onDismiss)
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.bottom, Tokens.Space.xl)
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

private struct ConfirmationView: View {
    let transcript: String
    let parser: VoiceMealParser
    let onSave: (String) -> Void
    let onRetake: () -> Void
    let onDismiss: () -> Void

    @State private var edited: String

    init(
        transcript: String,
        parser: VoiceMealParser,
        onSave: @escaping (String) -> Void,
        onRetake: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.transcript = transcript
        self.parser = parser
        self.onSave = onSave
        self.onRetake = onRetake
        self.onDismiss = onDismiss
        self._edited = State(initialValue: transcript)
    }

    private var parsedItems: [FoodItem] {
        parser.parseMultiple(edited)
    }

    var body: some View {
        VStack(spacing: Tokens.Space.lg) {
            HStack {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Tokens.Palette.inkMuted)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Tokens.Palette.surfaceMuted))
                }
                .accessibilityLabel(Text("Zamknij"))
                Spacer()
                Text("Sprawdź wpis")
                    .font(Tokens.Font.headline)
                    .foregroundStyle(Tokens.Palette.ink)
                Spacer()
                Color.clear.frame(width: 36, height: 36)
            }
            .padding(.horizontal, Tokens.Space.screenPadding)
            .padding(.top, Tokens.Space.md)

            ScrollView {
                Card {
                    VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                        Text("Co usłyszeliśmy")
                            .font(Tokens.Font.footnote)
                            .foregroundStyle(Tokens.Palette.inkMuted)
                        TextEditor(text: $edited)
                            .font(Tokens.Font.body)
                            .foregroundStyle(Tokens.Palette.ink)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 120)
                    }
                }
                Card {
                    VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                        Text("Co zapiszemy")
                            .font(Tokens.Font.footnote)
                            .foregroundStyle(Tokens.Palette.inkMuted)
                        ForEach(parsedItems) { item in
                            HStack(alignment: .firstTextBaseline) {
                                Text(item.name)
                                    .font(Tokens.Font.body)
                                    .foregroundStyle(Tokens.Palette.ink)
                                Spacer(minLength: Tokens.Space.sm)
                                Text("\(Int(item.quantityGrams)) g · \(Int(item.caloriesKcal)) kcal")
                                    .font(Tokens.Font.caption)
                                    .foregroundStyle(Tokens.Palette.inkMuted)
                            }
                            if item.id != parsedItems.last?.id {
                                Divider().background(Tokens.Palette.separator)
                            }
                        }
                    }
                }
                Card(background: Tokens.Palette.primarySoft, elevation: Tokens.Shadow.card) {
                    HStack(spacing: Tokens.Space.sm) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(Tokens.Palette.primary)
                        Text("Wkrótce: Ola sama zamieni opis w wpis z kaloriami. Teraz zapisujemy placeholder.")
                            .font(Tokens.Font.footnote)
                            .foregroundStyle(Tokens.Palette.ink)
                    }
                }
            }
            .padding(.horizontal, Tokens.Space.screenPadding)

            VStack(spacing: Tokens.Space.sm) {
                PrimaryButton(title: "Zapisz", systemImage: "checkmark") { onSave(edited) }
                Button(action: onRetake) {
                    Text("Spróbuj jeszcze raz")
                        .font(Tokens.Font.callout)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                }
            }
            .padding(.horizontal, Tokens.Space.screenPadding)
            .padding(.bottom, Tokens.Space.xl)
        }
    }
}
