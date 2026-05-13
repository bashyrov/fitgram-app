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
        static let welcomeSkip = "onboarding.welcome.skip"
        static let goalContinue = "onboarding.goal.continue"
        static let profileContinue = "onboarding.profile.continue"
        static let dietaryContinue = "onboarding.dietary.continue"
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
        static let streakExplain = "today.streak.explain"
        static let emptyMealsCallout = "today.meals.empty"
        static let suggestedCookButton = "today.suggested.cook"
        static let dayScrubPrev = "today.scrub.prev"
        static let dayScrubNext = "today.scrub.next"
        static let dayScrubLabel = "today.scrub.label"
        static let waterAdd = "today.water.add"
        static let waterUndo = "today.water.undo"
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
        static let exportCSV = "profile.row.exportCSV"
        static let exportBundle = "profile.row.exportBundle"
        static let helpFAQ = "profile.row.help"
        static let restartOnboarding = "profile.row.restartOnboarding"
        static let cleanupPhotos = "profile.row.cleanupPhotos"
        static let signOut = "profile.row.signOut"
        static let deleteAccount = "profile.row.delete"
    }

    enum QuickDB {
        static let searchField = "quickdb.search"
        static let addCustom = "quickdb.menu.addCustom"
        static let scanLabel = "quickdb.menu.scanLabel"
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
