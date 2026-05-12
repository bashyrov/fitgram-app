import SwiftUI
import UIKit

/// Personal-code sheet — generates a QR + plain text fallback so the user
/// can hand their Mealgram id to a friend over any channel. Decoding back
/// into an `addFriend` flow lands when the social backend is wired.
struct MyCodeSheet: View {
    let userID: String
    let displayName: String?
    let onDismiss: () -> Void

    @State private var qrImage: UIImage?
    @State private var copied = false

    var body: some View {
        NavigationStack {
            ZStack {
                Tokens.Palette.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: Tokens.Space.lg) {
                        intro
                        qrTile
                        codeRow
                    }
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.vertical, Tokens.Space.lg)
                }
            }
            .navigationTitle(Text("Mój kod"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Zamknij", action: onDismiss)
                }
            }
        }
        .task {
            qrImage = QRCodeRenderer.image(for: QRCodeRenderer.deepLink(forUserID: userID))
        }
    }

    private var intro: some View {
        Card(background: Tokens.Palette.primarySoft) {
            VStack(alignment: .leading, spacing: 4) {
                if let displayName, !displayName.isEmpty {
                    Text(displayName)
                        .font(Tokens.Font.headline)
                        .foregroundStyle(Tokens.Palette.ink)
                }
                Text("Pokaż kod znajomemu — wystarczy że go zeskanuje albo przepisze.")
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var qrTile: some View {
        Card(elevation: Tokens.Shadow.float) {
            ZStack {
                if let qrImage {
                    Image(uiImage: qrImage)
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .padding(Tokens.Space.md)
                } else {
                    RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                        .fill(Tokens.Palette.surfaceMuted)
                        .aspectRatio(1, contentMode: .fit)
                }
            }
        }
    }

    private var codeRow: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                Text("Twój identyfikator")
                    .font(Tokens.Font.headline)
                    .foregroundStyle(Tokens.Palette.ink)
                Text(userID)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(Tokens.Palette.inkMuted)
                    .padding(Tokens.Space.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                            .fill(Tokens.Palette.surfaceMuted)
                    )
                Button {
                    UIPasteboard.general.string = userID
                    copied = true
                    Task {
                        try? await Task.sleep(nanoseconds: 1_800_000_000)
                        copied = false
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        Text(copied ? "Skopiowane" : "Skopiuj")
                            .font(Tokens.Font.bodyEmphasized)
                    }
                    .foregroundStyle(Tokens.Palette.primary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
