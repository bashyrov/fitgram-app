import Foundation
import OSLog

/// Email + password accounts on Supabase. Sign-up returns a session right
/// away because "Confirm email" is disabled for the project, so there is no
/// inbox step. The UI drives this provider directly through
/// `AuthService.signInWithEmail(email:password:createAccount:)`.
@MainActor
final class EmailAuthProvider: AuthProvider {
    let kind: AuthProviderKind = .email

    /// Supabase's default minimum password length.
    static let minimumPasswordLength = 8

    private let supabase: SupabaseAuthExchange

    init(supabase: SupabaseAuthExchange = SupabaseAuthExchange()) {
        self.supabase = supabase
    }

    func signIn() async throws -> AuthCredentials {
        // Email needs the address and password from the sheet; the generic
        // one-tap path is intentionally unsupported.
        throw AuthError.providerNotConfigured(.email)
    }

    func signOut() async {}

    func signIn(email: String, password: String, createAccount: Bool) async throws -> AuthCredentials {
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard Self.isPlausibleEmail(email) else {
            throw EmailAuthError.invalidEmail
        }
        // Only new accounts must meet the password rules; an account made
        // under an older, looser rule must still be able to sign in.
        let isAcceptable = createAccount ? Self.meetsRequirements(password) : !password.isEmpty
        guard isAcceptable else {
            throw EmailAuthError.weakPassword
        }
        do {
            return createAccount
                ? try await supabase.signUp(email: email, password: password)
                : try await supabase.signIn(email: email, password: password)
        } catch let error as SupabaseAuthExchange.ExchangeError {
            throw Self.map(error, createAccount: createAccount)
        } catch let error as URLError {
            Logger.auth.error("Email auth network error: \(error.code.rawValue)")
            throw EmailAuthError.network
        }
    }

    /// Mirrors the Supabase rule for new passwords: the minimum length plus
    /// at least one ASCII lowercase letter, uppercase letter and digit.
    static func meetsRequirements(_ password: String) -> Bool {
        password.count >= minimumPasswordLength
            && password.contains { ("a"..."z").contains($0) }
            && password.contains { ("A"..."Z").contains($0) }
            && password.contains { ("0"..."9").contains($0) }
    }

    static func isPlausibleEmail(_ email: String) -> Bool {
        let parts = email.split(separator: "@")
        return parts.count == 2 && !parts[0].isEmpty && parts[1].contains(".") && !email.contains(" ")
    }

    static func map(_ error: SupabaseAuthExchange.ExchangeError, createAccount: Bool) -> EmailAuthError {
        switch error {
        case .notConfigured:
            return .notConfigured
        case .emailConfirmationRequired:
            return .confirmationRequired
        case .invalidResponse:
            return .unknown
        case .http(let status, let body):
            Logger.auth.error("Email auth failed: \(status) \(body, privacy: .public)")
            let lowered = body.lowercased()
            if lowered.contains("already registered") || lowered.contains("user_already_exists") {
                return .accountExists
            }
            if lowered.contains("weak_password") || lowered.contains("password should be") {
                return .weakPassword
            }
            if lowered.contains("email_not_confirmed") {
                return .confirmationRequired
            }
            if !createAccount, status == 400 || lowered.contains("invalid_credentials") {
                return .invalidCredentials
            }
            if status == 429 {
                return .rateLimited
            }
            return .unknown
        }
    }
}

enum EmailAuthError: LocalizedError, Equatable {
    case invalidEmail
    case weakPassword
    case invalidCredentials
    case accountExists
    case confirmationRequired
    case rateLimited
    case network
    case notConfigured
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidEmail: return L("Wpisz poprawny adres e-mail.")
        case .weakPassword: return L("Hasło: min. 8 znaków, mała i wielka litera oraz cyfra.")
        case .invalidCredentials: return L("Nieprawidłowy e-mail lub hasło.")
        case .accountExists: return L("Konto z tym adresem już istnieje. Zaloguj się.")
        case .confirmationRequired: return L("Konto wymaga potwierdzenia e-mail. Spróbuj ponownie później.")
        case .rateLimited: return L("Za dużo prób. Odczekaj chwilę i spróbuj ponownie.")
        case .network: return L("Brak połączenia z internetem.")
        case .notConfigured: return L("Logowanie e-mailem jest chwilowo niedostępne.")
        case .unknown: return L("Nie udało się zalogować. Spróbuj ponownie za chwilę.")
        }
    }
}
