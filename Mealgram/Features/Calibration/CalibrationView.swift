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
            ZStack {
                Tokens.Palette.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: Tokens.Space.lg) {
                        explainer
                        adjustmentCard
                        referenceCard
                        if let calibration {
                            sampleCountCard(calibration)
                        }
                        PrimaryButton(title: "Zapisz", systemImage: "checkmark", action: save)
                        Button(role: .destructive) {
                            isResetConfirmed = true
                        } label: {
                            HStack(spacing: Tokens.Space.sm) {
                                Image(systemName: "arrow.counterclockwise")
                                Text("Resetuj kalibrację")
                            }
                            .font(Tokens.Font.bodyEmphasized)
                            .foregroundStyle(Tokens.Palette.warning)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Tokens.Space.md)
                        }
                        .buttonStyle(.plain)
                        .disabled((calibration?.sampleCount ?? 0) == 0 && draftFactor == 1)
                    }
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.vertical, Tokens.Space.lg)
                }
                .task { await load() }
            }
            .navigationTitle(Text("Kalibracja"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Zamknij", action: onDismiss)
                }
            }
            .confirmationDialog(
                "Zresetować kalibrację?",
                isPresented: $isResetConfirmed,
                titleVisibility: .visible
            ) {
                Button("Resetuj", role: .destructive, action: reset)
                Button("Anuluj", role: .cancel) {}
            } message: {
                Text("Korekta wróci do ×1.00, licznik skanów wyzeruje się.")
            }
        }
    }

    // MARK: - Sections

    private var explainer: some View {
        Card(background: Tokens.Palette.primarySoft, elevation: Tokens.Shadow.card) {
            HStack(alignment: .top, spacing: Tokens.Space.md) {
                Image(systemName: "wand.and.stars")
                    .font(.title2)
                    .foregroundStyle(Tokens.Palette.primary)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Dopasuj AI do siebie")
                        .font(Tokens.Font.bodyEmphasized)
                        .foregroundStyle(Tokens.Palette.ink)
                    Text(
                        "Jeśli widzisz, że wpisy są zwykle za duże albo za małe, przesuń suwak."
                            + " Pomożemy AI lepiej oceniać Twoje porcje."
                    )
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                }
            }
        }
    }

    private var adjustmentCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                HStack {
                    Text("Korekta porcji")
                        .font(Tokens.Font.headline)
                        .foregroundStyle(Tokens.Palette.ink)
                    Spacer()
                    Text(String(format: "×%.2f", draftFactor))
                        .font(Tokens.Font.bodyEmphasized)
                        .foregroundStyle(Tokens.Palette.primary)
                }
                Slider(
                    value: $draftFactor,
                    in: CalibrationService.factorBounds,
                    step: 0.05
                )
                .tint(Tokens.Palette.primary)
                HStack {
                    Text("Za małe")
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Palette.inkSubtle)
                    Spacer()
                    Text("OK")
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Palette.inkSubtle)
                    Spacer()
                    Text("Za duże")
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Palette.inkSubtle)
                }
            }
        }
    }

    private var referenceCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                Text("Punkt odniesienia")
                    .font(Tokens.Font.headline)
                    .foregroundStyle(Tokens.Palette.ink)
                Text("Wybierz, co najczęściej widać obok talerza. Pomoże to AI w przyszłych skanach.")
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                Picker("Punkt odniesienia", selection: $draftReference) {
                    Text("Karta").tag(ReferenceObjectKind.creditCard)
                    Text("Dłoń").tag(ReferenceObjectKind.eatingHand)
                    Text("Widelec").tag(ReferenceObjectKind.fork)
                    Text("Inne").tag(ReferenceObjectKind.generic)
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private func sampleCountCard(_ calibration: Calibration) -> some View {
        Card {
            HStack(spacing: Tokens.Space.md) {
                Image(systemName: "chart.bar.xaxis")
                    .foregroundStyle(Tokens.Palette.primary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(calibration.sampleCount) skanów do tej pory")
                        .font(Tokens.Font.body)
                        .foregroundStyle(Tokens.Palette.ink)
                    Text(updatedLabel(calibration.lastUpdated))
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                }
                Spacer(minLength: 0)
            }
        }
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
