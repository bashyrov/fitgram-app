import SwiftUI

/// Tap-the-day-label sheet from the Today screen. Wraps a graphical
/// DatePicker constrained at today as the max, plus a quick "Wróć do
/// dziś" shortcut.
struct DateJumpSheet: View {
    let viewingDate: Date
    let onPick: (Date) -> Void
    let onToday: () -> Void
    let onDismiss: () -> Void

    @State private var draftDate: Date

    init(
        viewingDate: Date,
        onPick: @escaping (Date) -> Void,
        onToday: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.viewingDate = viewingDate
        self.onPick = onPick
        self.onToday = onToday
        self.onDismiss = onDismiss
        self._draftDate = State(initialValue: viewingDate)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Tokens.Palette.background.ignoresSafeArea()
                VStack(spacing: Tokens.Space.md) {
                    DatePicker(
                        "Wybierz dzień",
                        selection: $draftDate,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .tint(Tokens.Palette.primary)

                    PrimaryButton(title: "Pokaż ten dzień", systemImage: "calendar") {
                        onPick(draftDate)
                    }
                    .padding(.horizontal, Tokens.Space.screenPadding)

                    Button("Wróć do dziś", action: onToday)
                        .font(Tokens.Font.bodyEmphasized)
                        .foregroundStyle(Tokens.Palette.primary)

                    Spacer(minLength: 0)
                }
                .padding(.top, Tokens.Space.md)
            }
            .navigationTitle(Text("Wybierz dzień"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Zamknij", action: onDismiss)
                }
            }
        }
    }
}
