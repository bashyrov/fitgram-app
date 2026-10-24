import SwiftData
import SwiftUI

/// Profile sub-screen: tune the AI's portion estimates manually. The
/// vision-based "card on plate" auto-calibration ships later in Phase 2;
/// today this is a simple ±40 % slider the user can nudge when they feel
/// the AI is consistently off.
struct CalibrationView: View {
    let userRemoteID: String
    let service: CalibrationService
    let onDismiss: () -> Void

    @State private var calibration: Calibration?
    @State private var draftFactor: Double = 1.0
    @State private var draftReference: ReferenceObjectKind = .creditCard
    @State private var isResetConfirmed = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    MonoH1(text: L("Dopasuj AI do siebie"), sub: headerSubtitle, kicker: L("Kalibracja"))
                    adjustmentCard
                        .padding(.top, 16)
                    referenceCard
                        .padding(.top, 10)
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.bottom, Tokens.Space.lg)
            }
            .scrollIndicators(.hidden)
            .background(Tokens.Palette.background.ignoresSafeArea())
            .task { await load() }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                MonoBottomBar {
                    MonoButton(title: L("Resetuj kalibrację"), kind: .danger, icon: "arrow.counterclockwise") {
                        isResetConfirmed = true
                    }
                    .disabled((calibration?.sampleCount ?? 0) == 0 && draftFactor == 1)
                }
            }
            .monoNavigationTitle(L("Kalibracja"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    MonoNavText(title: L("Zamknij"), action: onDismiss)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    MonoNavPill(title: L("Save"), action: save)
                }
            }
            .confirmationDialog(
                "Zresetować kalibrację?",
                isPresented: $isResetConfirmed,
                titleVisibility: .visible
            ) {
                Button("Reset", role: .destructive, action: reset)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Calibration resets to ×1.00, scan counter clears.")
            }
        }
    }

    // MARK: - Sections

    private var headerSubtitle: String {
        guard let calibration else {
            return L("Jeśli widzisz, że wpisy są zwykle za duże albo za małe, przesuń suwak.")
        }
        let count = String.localizedStringWithFormat(L("%lld skanów do tej pory"), calibration.sampleCount)
        guard calibration.sampleCount > 0 else { return count }
        return count + " · " + updatedLabel(calibration.lastUpdated)
    }

    private var adjustmentCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                MonoLabel(text: L("Korekta porcji"))
                Spacer()
                Text(String(format: "×%.2f", draftFactor))
                    .font(Tokens.Font.monoNumber(26))
                    .foregroundStyle(Tokens.Palette.ink)
                    .monospacedDigit()
            }
            VStack(spacing: 6) {
                Slider(
                    value: $draftFactor,
                    in: CalibrationService.factorBounds,
                    step: 0.05
                )
                .tint(Tokens.Mono.strong)
                HStack {
                    Text("Za małe")
                    Spacer()
                    Text("Za duże")
                }
                .font(Tokens.Font.manrope(11, weight: 700))
                .foregroundStyle(Tokens.Mono.muted)
            }
        }
        .monoCard(padding: 16)
    }

    private var referenceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            MonoLabel(text: L("Punkt odniesienia"))
            Text("Wybierz, co najczęściej widać obok talerza. Pomoże to AI w przyszłych skanach.")
                .font(Tokens.Font.manrope(12, weight: 600))
                .foregroundStyle(Tokens.Mono.muted)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
            MonoSegmented(
                selection: $draftReference,
                options: [
                    (value: ReferenceObjectKind.creditCard, title: L("Karta")),
                    (value: ReferenceObjectKind.eatingHand, title: L("Hand")),
                    (value: ReferenceObjectKind.fork, title: L("Widelec")),
                    (value: ReferenceObjectKind.generic, title: L("Inne")),
                ]
            )
        }
        .monoCard(padding: 16)
    }

    // MARK: - Helpers

    private func load() async {
        do {
            let stored = try service.current(forUser: userRemoteID)
            calibration = stored
            draftFactor = stored.portionAdjustmentFactor
            draftReference = stored.referenceObject
        } catch {
            calibration = nil
        }
    }

    private func save() {
        try? service.updateFactor(
            draftFactor,
            referenceObject: draftReference,
            forUser: userRemoteID
        )
        onDismiss()
    }

    private func reset() {
        try? service.reset(forUser: userRemoteID)
        Haptics.warning()
        Task { await load() }
    }

    private func updatedLabel(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale.current
        formatter.unitsStyle = .full
        return "Ostatnio: \(formatter.localizedString(for: date, relativeTo: Date()))"
    }
}
