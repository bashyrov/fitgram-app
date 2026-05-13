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
                HStack(spacing: Tokens.Space.md) {
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

                    ShareLink(
                        item: inviteMessage,
                        subject: Text("Dodaj mnie na Mealgram"),
                        preview: SharePreview(
                            "Mealgram",
                            icon: Image(systemName: "leaf.fill")
                        )
                    ) {
                        HStack(spacing: 6) {
                            Image(systemName: "square.and.arrow.up")
                            Text("Udostępnij")
                                .font(Tokens.Font.bodyEmphasized)
                        }
                        .foregroundStyle(Tokens.Palette.primary)
                    }
                }
            }
        }
    }

    /// Plain-text invite the user can paste anywhere. Includes the deep
    /// link form of the id so any client that recognises the
    /// mealgram:// scheme (the app itself, once we ship Universal Links
    /// for mealgram.pl, an Open Graph preview later) can route on tap.
    private var inviteMessage: String {
        let opener: String
        if let displayName, !displayName.isEmpty {
            opener = "\(displayName) zaprasza Cię do Mealgram"
        } else {
            opener = "Dodaj mnie na Mealgram"
        }
        return """
            \(opener)
            Mój kod: \(userID)
            \(QRCodeRenderer.deepLink(forUserID: userID))
            """
    }
}
