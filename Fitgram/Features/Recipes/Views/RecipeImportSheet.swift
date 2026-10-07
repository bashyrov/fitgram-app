import SwiftUI
import UIKit

/// Lightweight URL paste-and-import sheet. Hands the parsed draft back
/// via `onImported` so `RecipeListView` can route it into the existing
/// form sheet for the user to refine before saving.
struct RecipeImportSheet: View {
    let importer: RecipeURLImporter
    let onImported: (RecipeDraft) -> Void
    let onDismiss: () -> Void

    @State private var urlString: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var canImport: Bool {
        !isLoading && !urlString.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    MonoH1(
                        text: L("Wklej link do przepisu"),
                        sub: L("Działa z większością stron — m.in. kwestiasmaku.com, hreceptu.pl, allrecipes.com.")
                    )
                    .padding(.bottom, 6)
                    urlCard
                    if let errorMessage {
                        errorCard(errorMessage)
                    }
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Tokens.Palette.background.ignoresSafeArea())
            .monoNavigationTitle(L("Importuj przepis"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    MonoNavText(title: L("Cancel"), action: onDismiss)
                }
            }
            .safeAreaInset(edge: .bottom) {
                MonoBottomBar {
                    Button {
                        Task { await runImport() }
                    } label: {
                        HStack(spacing: 8) {
                            if isLoading {
                                ProgressView()
                                    .tint(Tokens.Mono.onHero)
                            } else {
                                Image(systemName: "square.and.arrow.down")
                                    .font(.system(size: 15, weight: .bold))
                            }
                            Text(isLoading ? L("Pobieram…") : L("Importuj"))
                        }
                    }
                    .buttonStyle(MonoButtonStyle(kind: .dark))
                    .disabled(!canImport)
                }
            }
        }
    }

    private var urlCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            MonoField(label: TL(pl: "Link", en: "Link", uk: "Посилання", ru: "Ссылка", es: "Enlace")) {
                HStack(spacing: 8) {
                    TextField("https://...", text: $urlString)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                    if urlString.isEmpty, clipboardURL != nil {
                        Button {
                            pasteFromClipboard()
                        } label: {
                            Text("Wklej")
                                .font(Tokens.Font.manrope(12, weight: 800))
                                .foregroundStyle(Tokens.Palette.ink)
                                .padding(.horizontal, 10)
                                .frame(height: 32)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Tokens.Mono.track)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text("Wklej link ze schowka"))
                    }
                }
            }
            MonoButton(title: L("Wklej link ze schowka"), kind: .outline, icon: "doc.on.clipboard", height: 44) {
                pasteFromClipboard()
            }
            .disabled(clipboardURL == nil)
        }
        .monoCard(padding: 16)
    }

    private func errorCard(_ message: String) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Tokens.Mono.danger)
            Text(message)
                .font(Tokens.Font.manrope(12, weight: 600))
                .foregroundStyle(Tokens.Mono.muted)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .monoCard(padding: 16)
    }

    private func pasteFromClipboard() {
        if let url = clipboardURL {
            urlString = url
            Haptics.light()
        }
    }

    /// Reads the clipboard once when the field is empty; returns the
    /// string only if it parses as a URL with an http(s) scheme. We
    /// don't subscribe to clipboard change events because that triggers
    /// the system "X pasted from Y" banner on iOS 16+.
    private var clipboardURL: String? {
        guard UIPasteboard.general.hasURLs || UIPasteboard.general.hasStrings else { return nil }
        let raw = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let candidate = raw, !candidate.isEmpty,
            let url = URL(string: candidate),
            let scheme = url.scheme?.lowercased(),
            scheme == "http" || scheme == "https"
        else { return nil }
        return candidate
    }

    private func runImport() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let draft = try await importer.import(from: urlString)
            onImported(draft)
        } catch let error as RecipeURLImporter.ImportError {
            switch error {
            case .invalidURL:
                errorMessage = L("That doesn't look like a valid URL.")
            case .fetchFailed(let reason):
                errorMessage = String.localizedStringWithFormat(L("Couldn't fetch the page: %@"), reason)
            case .noRecipeFound:
                errorMessage = L("I couldn't find recipe data on that page.")
            }
        } catch {
            errorMessage = String.localizedStringWithFormat(L("Something went wrong: %@"), String(describing: error))
        }
    }
}
