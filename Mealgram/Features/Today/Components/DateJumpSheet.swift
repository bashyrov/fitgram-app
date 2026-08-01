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
                        "Pick a day",
                        selection: $draftDate,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .tint(Tokens.Palette.primary)

                    Spacer(minLength: 0)
                }
                .padding(.top, Tokens.Space.md)
                .frame(maxHeight: .infinity, alignment: .top)
            }
            .safeAreaInset(edge: .bottom) {
                bottomActions
            }
            .navigationTitle(Text("Pick a day"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", action: onDismiss)
                }
            }
        }
    }

    private var bottomActions: some View {
        VStack(spacing: Tokens.Space.sm) {
            PrimaryButton(title: "Show this day", systemImage: "calendar") {
                onPick(draftDate)
            }

            Button(action: onToday) {
                Text("Back to today")
                    .font(Tokens.Font.bodyEmphasized)
                    .foregroundStyle(Tokens.Palette.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Tokens.Space.screenPadding)
        .padding(.top, Tokens.Space.md)
        .padding(.bottom, Tokens.Space.sm)
        .background(.regularMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Tokens.Palette.separator.opacity(0.7))
                .frame(height: 0.5)
        }
    }
}
