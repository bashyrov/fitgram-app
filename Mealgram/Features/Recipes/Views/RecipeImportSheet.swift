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

    var body: some View {
        NavigationStack {
            ZStack {
                Tokens.Palette.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: Tokens.Space.lg) {
                        intro
                        urlField
                        if let errorMessage {
                            Text(errorMessage)
                                .font(Tokens.Font.footnote)
                                .foregroundStyle(Tokens.Palette.warning)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        PrimaryButton(
                            title: isLoading ? "Pobieram…" : "Importuj",
                            systemImage: "square.and.arrow.down",
                            isEnabled: !isLoading && !urlString.trimmingCharacters(in: .whitespaces).isEmpty
                        ) {
                            Task { await runImport() }
                        }
                    }
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.vertical, Tokens.Space.lg)
                }
            }
            .navigationTitle(Text("Importuj przepis"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Anuluj", action: onDismiss)
                }
            }
        }
    }

    private var intro: some View {
        Card(background: Tokens.Palette.primarySoft) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Wklej link do przepisu")
                    .font(Tokens.Font.bodyEmphasized)
                    .foregroundStyle(Tokens.Palette.ink)
                Text("Działa z większością stron — m.in. kwestiasmaku.com, hreceptu.pl, allrecipes.com.")
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var urlField: some View {
        HStack(spacing: Tokens.Space.sm) {
            Image(systemName: "link")
                .foregroundStyle(Tokens.Palette.inkMuted)
            TextField("https://...", text: $urlString)
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                .autocorrectionDisabled()
            if urlString.isEmpty, clipboardURL != nil {
                Button {
                    if let url = clipboardURL {
                        urlString = url
                        Haptics.light()
                    }
                } label: {
                    Text("Wklej")
                        .font(Tokens.Font.footnote.bold())
                        .foregroundStyle(Tokens.Palette.primary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Wklej link ze schowka"))
            }
        }
        .padding(Tokens.Space.md)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                .fill(Tokens.Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                .stroke(Tokens.Palette.separator, lineWidth: 1)
        )
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
                errorMessage = String(localized: "To nie wygląda na poprawny adres URL.")
            case .fetchFailed(let reason):
                errorMessage = String(localized: "Nie udało się pobrać strony: \(reason)")
            case .noRecipeFound:
                errorMessage = String(localized: "Na tej stronie nie znalazłam danych przepisu.")
            }
        } catch {
            errorMessage = String(describing: error)
        }
    }
}
