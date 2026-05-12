import Foundation

/// Central catalogue of accessibility identifiers. Anywhere the UI is
/// reached by an XCUITest goes here so test code never spells a string
/// twice. Convention: `<feature>.<element>.<role>`, lowercased,
/// dot-separated.
enum A11yID {
    enum Auth {
        static let appleButton = "auth.button.apple"
        static let googleButton = "auth.button.google"
        static let emailButton = "auth.button.email"
        static let errorBanner = "auth.error.banner"
    }

    enum Onboarding {
        static let welcomeStart = "onboarding.welcome.start"
        static let goalContinue = "onboarding.goal.continue"
        static let profileContinue = "onboarding.profile.continue"
        static let firstScanContinue = "onboarding.firstScan.continue"
        static let calibrationContinue = "onboarding.calibration.continue"
        static let notificationContinue = "onboarding.notification.continue"
        static let paywallContinue = "onboarding.paywall.continue"
    }

    enum Tab {
        static let today = "tab.today"
        static let add = "tab.add"
        static let progress = "tab.progress"
        static let profile = "tab.profile"
    }

    enum Today {
        static let streakProfileTap = "today.streak.profile"
        static let emptyMealsCallout = "today.meals.empty"
        static let suggestedCookButton = "today.suggested.cook"
    }

    enum Add {
        static let photoOption = "add.option.photo"
        static let barcodeOption = "add.option.barcode"
        static let quickDBOption = "add.option.quickDB"
        static let voiceOption = "add.option.voice"
        static let recipeOption = "add.option.recipe"
    }

    enum Scan {
        static let shutter = "scan.shutter"
        static let saveToDiary = "scan.results.save"
        static let addItem = "scan.results.addItem"
    }

    enum Profile {
        static let editGoals = "profile.row.editGoals"
        static let preferences = "profile.row.preferences"
        static let calibration = "profile.row.calibration"
        static let weight = "profile.row.weight"
        static let exportData = "profile.row.export"
        static let signOut = "profile.row.signOut"
        static let deleteAccount = "profile.row.delete"
    }

    enum Recipes {
        static let add = "recipes.button.add"
        static let cookFromDetail = "recipes.detail.cook"
        static let saveForm = "recipes.form.save"
    }

    enum Weight {
        static let addEntry = "weight.button.add"
        static let importHealth = "weight.button.importHealth"
        static let saveEntry = "weight.entry.save"
    }
}
