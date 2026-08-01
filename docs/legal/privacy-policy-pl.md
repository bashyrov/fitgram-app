# Polityka prywatności Mealgram

**Wersja:** 1.0
**Data wejścia w życie:** 2026-06-01
**Administrator:** [TWOJA_NAZWA_JDG], NIP [NIP], REGON [REGON], adres [ADRES]
**Kontakt:** hello@mealgram.xyz

## 1. Kto jest administratorem Twoich danych

Administratorem Twoich danych osobowych zbieranych w aplikacji Mealgram (dalej "Aplikacja") jest [TWOJA_NAZWA_JDG] z siedzibą w [MIASTO], NIP [NIP].

W sprawach związanych z ochroną danych osobowych możesz się z nami skontaktować pod adresem **hello@mealgram.xyz**.

## 2. Jakie dane zbieramy

### 2.1. Dane konta
Gdy logujesz się do Aplikacji za pomocą Apple ID, Google lub adresu e-mail, zbieramy:
- identyfikator zewnętrzny dostawcy uwierzytelniania (np. Sub Apple ID)
- adres e-mail (jeśli go udostępniłeś)
- imię (jeśli je udostępniłeś — Apple/Google pozwalają na ukrycie)

### 2.2. Dane zdrowotne i żywieniowe
Gdy korzystasz z Aplikacji, dobrowolnie podajesz:
- wagę, wzrost, datę urodzenia, płeć biologiczną (do obliczenia BMR/TDEE)
- poziom aktywności, cel (utrata / utrzymanie / przyrost wagi)
- preferencje żywieniowe (wegetariańskie, bez glutenu, itp.)
- spożyte posiłki — nazwa, gramatura, kalorie, makroskładniki
- zdjęcia posiłków (opcjonalnie)
- nagrania głosowe (opcjonalnie, przetwarzane lokalnie)
- skany kodów kreskowych produktów
- ocenę posiłków (1–5 gwiazdek)
- tagi posiłków
- notatki tekstowe
- wpisy wagi i notatki o samopoczuciu
- dziennik wody

### 2.3. Dane techniczne
Automatycznie zbieramy:
- identyfikator urządzenia (anonimowy, zarządzany przez Apple)
- wersję systemu iOS, model urządzenia (do raportowania crashy)
- język i strefę czasową
- dane diagnostyczne błędów aplikacji (jeśli wyraziłeś zgodę)
- anonimowe dane o sposobie korzystania (jeśli wyraziłeś zgodę)

### 2.4. Dane subskrypcji
Gdy kupujesz subskrypcję premium:
- identyfikator transakcji App Store
- status subskrypcji (aktywna / wygasła / w okresie próbnym)
- daty rozpoczęcia i odnowienia

**Nie zbieramy** numerów kart płatniczych — wszystkie płatności obsługuje wyłącznie Apple.

## 3. Po co przetwarzamy Twoje dane (cele)

| Cel | Podstawa prawna (RODO) |
|---|---|
| Świadczenie usługi (logowanie, zapisywanie posiłków, statystyki) | Art. 6 ust. 1 lit. b — wykonanie umowy |
| Liczenie kalorii i makroskładników | Art. 9 ust. 2 lit. a — wyraźna zgoda (dane zdrowotne) |
| Rozpoznawanie zdjęć posiłków przez AI | Art. 9 ust. 2 lit. a — wyraźna zgoda |
| Wysyłanie powiadomień push | Art. 6 ust. 1 lit. a — zgoda systemu iOS |
| Diagnostyka błędów (Sentry) | Art. 6 ust. 1 lit. f — uzasadniony interes |
| Analityka anonimowa (PostHog) | Art. 6 ust. 1 lit. a — zgoda |
| Obsługa subskrypcji | Art. 6 ust. 1 lit. b — wykonanie umowy |
| Wypełnienie obowiązków prawnych (np. zwrot środków) | Art. 6 ust. 1 lit. c |

## 4. Komu udostępniamy dane

Twoje dane przekazujemy następującym podmiotom przetwarzającym:

### 4.1. Apple Inc.
Logowanie Apple ID, zakupy w aplikacji, push notifications, iCloud sync (jeśli włączysz). Dane przetwarzane zgodnie z polityką Apple.

### 4.2. Supabase Inc. (USA + UE)
Backend uwierzytelniania i przechowywanie danych konta. Serwery w Unii Europejskiej (Frankfurt). [Polityka prywatności Supabase](https://supabase.com/privacy).

### 4.3. Cloudflare Inc. (globalnie)
Proxy dla wywołań do AI (Gemini, Claude). Dane przechodzą przez Cloudflare Workers, nie są przechowywane dłużej niż 30 dni cache. [Polityka Cloudflare](https://www.cloudflare.com/privacypolicy/).

### 4.4. Google LLC (Gemini API)
Analiza zdjęć posiłków przez AI. Zdjęcia przesyłane są bez identyfikatora użytkownika, usuwane natychmiast po przetworzeniu. [Polityka Google AI](https://policies.google.com/privacy).

### 4.5. Anthropic PBC (Claude API)
Generowanie cotygodniowych podsumowań AI coach "Ola". Przekazujemy anonimowe podsumowania statystyk, bez nazwisk i e-maili. [Polityka Anthropic](https://www.anthropic.com/legal/privacy).

### 4.6. RevenueCat Inc.
Obsługa subskrypcji premium. Przekazujemy anonimowy identyfikator użytkownika. [Polityka RevenueCat](https://www.revenuecat.com/privacy).

### 4.7. Sentry GmbH (UE)
Diagnostyka błędów aplikacji. Stack trace nie zawiera danych osobowych. [Polityka Sentry](https://sentry.io/privacy/).

### 4.8. PostHog Inc.
Anonimowa analityka produktowa. Nie używamy IP użytkownika, nie używamy fingerprintingu. [Polityka PostHog](https://posthog.com/privacy).

### 4.9. Open Food Facts (Open Database License)
Publiczna baza produktów spożywczych. Skanowanie kodu kreskowego nie ujawnia tożsamości użytkownika.

**Nie sprzedajemy** Twoich danych żadnym podmiotom trzecim. Nie udostępniamy ich do celów reklamowych.

## 5. Transfer danych poza UE

- Apple — USA, na podstawie standardowych klauzul umownych (SCC)
- Google — USA, SCC + Data Processing Addendum
- Anthropic — USA, SCC
- RevenueCat — USA, SCC
- PostHog — USA, SCC + UE-US Data Privacy Framework

Wszystkie nasze podmioty przetwarzające zobowiązały się do przestrzegania RODO.

## 6. Jak długo przechowujemy dane

| Kategoria | Okres |
|---|---|
| Dane konta | Do usunięcia konta + 30 dni |
| Posiłki, waga, statystyki | Do usunięcia konta + 30 dni |
| Zdjęcia posiłków | Lokalnie do usunięcia + 7 dni; w chmurze (gdy włączysz sync) 90 dni |
| Diagnostyka błędów | 90 dni |
| Anonimowa analityka | 365 dni |
| Dane subskrypcji | 5 lat od ostatniej transakcji (obowiązek księgowy) |

## 7. Twoje prawa (RODO)

Masz prawo do:

1. **Dostępu do swoich danych** — eksport w formacie JSON/CSV/ZIP dostępny w Profilu → "Pełna paczka (ZIP)" lub na żądanie pod adresem hello@mealgram.xyz
2. **Sprostowania danych** — edytuj w aplikacji lub napisz do nas
3. **Usunięcia danych** ("prawo do bycia zapomnianym") — Profil → "Usuń konto", lub pod adresem hello@mealgram.xyz. Usuniemy w ciągu 30 dni
4. **Ograniczenia przetwarzania** — napisz na hello@mealgram.xyz
5. **Sprzeciwu wobec przetwarzania** — napisz na hello@mealgram.xyz
6. **Przenoszenia danych** — eksport JSON zawiera wszystkie dane w czytelnym formacie
7. **Cofnięcia zgody** w dowolnym momencie — bez wpływu na przetwarzanie sprzed cofnięcia
8. **Skargi do organu nadzorczego** — Urząd Ochrony Danych Osobowych (UODO), ul. Stawki 2, 00-193 Warszawa, [uodo.gov.pl](https://uodo.gov.pl)

## 8. Profilowanie i decyzje zautomatyzowane

Aplikacja używa algorytmów ("AI Coach Ola") do generowania spersonalizowanych podsumowań tygodniowych. Decyzje te:
- mają charakter informacyjny / motywujący
- nie wywołują skutków prawnych
- nie mają istotnego wpływu na Twoją sytuację

Nie używamy danych do profilowania reklamowego.

## 9. Bezpieczeństwo

Stosujemy:
- szyfrowanie połączeń (TLS 1.3)
- szyfrowane przechowywanie w iCloud Keychain dla tokenów
- ograniczenie dostępu pracowników do produkcyjnych baz danych
- regularne audyty bezpieczeństwa
- pseudonimizację w logach diagnostycznych

W razie naruszenia bezpieczeństwa danych powiadomimy Cię w ciągu 72 godzin zgodnie z RODO.

## 10. Dzieci

Aplikacja **nie jest przeznaczona dla osób poniżej 13. roku życia**. Świadomie nie zbieramy danych dzieci. Jeśli dowiemy się, że konto należy do osoby poniżej 13 roku życia, niezwłocznie je usuniemy.

Osoby w wieku 13–18 lat powinny uzyskać zgodę rodzica/opiekuna prawnego przed utworzeniem konta.

## 11. Zmiany polityki

Możemy zaktualizować tę politykę. O istotnych zmianach poinformujemy Cię:
- in-app powiadomieniem przy następnym uruchomieniu
- e-mailem (jeśli zostawiłeś adres)
- z 30-dniowym wyprzedzeniem przed wejściem zmian

Aktualna wersja jest zawsze dostępna pod adresem [mealgram.xyz/privacy](https://mealgram.xyz/privacy) i w aplikacji Profil → Pomoc / Polityka prywatności.

## 12. Kontakt

E-mail: **hello@mealgram.xyz**
Adres pocztowy: [TWÓJ_ADRES]
Inspektor Ochrony Danych (DPO): nie powołano (jednoosobowa firma)

---

*Ostatnia aktualizacja: 2026-06-01*
