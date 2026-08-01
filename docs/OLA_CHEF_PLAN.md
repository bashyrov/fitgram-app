# Kuchnia Oli Feature Plan

Goal: add a "Kuchnia Oli" flow inside the Add Meal menu that helps the user pick or generate a meal for a target calorie amount, then optionally view ingredients and recipe details before logging it.

## Product Decision

- [x] Replace the current Add Meal educational block "Co zapisujemy?" with a "Kuchnia Oli" entry block.
- [x] Keep the Add Meal menu as the main entry point for this feature.
- [x] Do not add a separate Today-screen block for the first version.
- [x] Position "Kuchnia Oli" visually between photo scan and the quick action grid, because it is a primary add-meal scenario.

## User Flow

- [x] User opens Add Meal.
- [x] User taps the "Kuchnia Oli" block.
- [x] User chooses target calories:
  - [x] quick chips: 300, 450, 600, 750, 900 kcal
  - [x] custom slider/input: 200-1200 kcal
  - [x] optional meal context: breakfast, lunch, dinner, snack
  - [x] optional preference chips: high protein, light, quick, vegetarian, budget, no cooking
- [x] App shows meal suggestions matching the target calories.
- [ ] Each suggestion shows:
  - [ ] translated dish name
  - [x] total calories
  - [x] serving size in grams
  - [x] macro summary
  - [x] cuisine/category
  - [x] estimated prep time when available
- [x] User taps a suggestion.
- [x] Detail page opens with:
  - [x] ingredient list
  - [x] grams per ingredient
  - [x] kcal per ingredient
  - [x] protein/carbs/fat per ingredient when available
  - [x] recipe steps when available
  - [x] "Add to diary" CTA
  - [x] "Save to my recipes" option
- [ ] Before final logging, user still lands on the standard portion confirmation page when needed.

## Free/Pro Limits

- [x] Add a new free-tier quota: 1 Kuchnia Oli request per local day.
- [x] Premium users have unlimited Kuchnia Oli requests.
- [x] Quota resets at the user's local midnight, using the same local-day logic as `UsageMeter`.
- [x] Show remaining requests inside the Kuchnia Oli block in Add Meal.
- [x] If free quota is exhausted, tap opens Paywall with a dedicated trigger/copy.
- [x] Viewing already returned/cached suggestions should not consume another request.
- [x] Logging a suggested dish should not consume an additional AI logged-meal quota unless a separate AI recalculation is requested.

## Data Library

- [x] Build a local food/dish library with 1000+ entries.
- [x] Library must include classic dishes and common products across cuisines, not only Polish food.
- [ ] Minimum cuisine coverage:
  - [ ] Polish
  - [ ] Ukrainian
  - [ ] American
  - [ ] Italian
  - [ ] French
  - [ ] Spanish
  - [ ] Mexican
  - [ ] Turkish
  - [ ] Greek
  - [ ] Georgian
  - [ ] Indian
  - [ ] Chinese
  - [ ] Japanese
  - [ ] Korean
  - [ ] Thai
  - [ ] Vietnamese
  - [ ] Middle Eastern
  - [ ] Mediterranean
  - [ ] German/Central European
  - [ ] Nordic
- [ ] Each dish entry should support:
  - [ ] canonical id
  - [ ] names in all app languages
  - [ ] cuisine
  - [ ] meal type tags
  - [ ] diet tags
  - [ ] default serving grams
  - [ ] calories per serving
  - [ ] macros per serving
  - [ ] ingredient breakdown when available
  - [ ] recipe steps when available
- [ ] Products should be stored per 100 g and reusable by the detailed portion flow.
- [ ] AI-returned products should be written into the product library only after normalized validation.

## Matching Logic

- [x] First search local library for meals near requested calories.
- [x] Calculate portion scaling so the suggested portion matches target calories.
- [x] Prefer realistic portion sizes.
- [x] Avoid absurd scaling, for example 35 g pizza or 900 g sauce.
- [x] Rank suggestions by:
  - [x] calorie fit
  - [x] meal type fit
  - [x] user's diet preferences
  - [x] protein preference
  - [x] prep-time preference
  - [ ] cuisine variety
- [ ] If local results are weak, call AI to generate or adapt suggestions.
- [ ] Cache AI-generated suggestions so re-opening the detail does not cost another request.

## AI Contract

- [ ] Add Worker endpoint for Kuchnia Oli suggestions.
- [ ] Request should include:
  - [ ] target calories
  - [ ] meal type
  - [ ] language
  - [ ] user preferences
  - [ ] available local library candidates
- [ ] Response should include structured JSON:
  - [ ] dish name
  - [ ] localized names
  - [ ] serving grams
  - [ ] total kcal
  - [ ] macros
  - [ ] ingredients with grams/kcal/macros
  - [ ] recipe steps if possible
  - [ ] cuisine/tags
- [ ] Reject vague or incomplete AI responses.
- [ ] Never log an AI suggestion directly without user confirmation.

## Add Meal UI

- [x] Replace `flowExplainer` in `AddMealSheet` with a Kuchnia Oli block.
- [x] New block should feel premium and iOS-native:
  - [x] soft material background
  - [x] strong food/chef iconography
  - [x] calorie target preview
  - [x] quota badge
  - [x] clear CTA
  - [x] no oversized marketing copy
- [x] Keep photo scan as the top hero.
- [x] Keep quick action grid below Kuchnia Oli.
- [x] Keep barcode and recents visible at the bottom without gradient overlap.

## Screens

- [x] `OlaChefTargetView`: target calorie selection.
- [x] `OlaChefSuggestionsView`: list of matched meals.
- [x] `OlaChefMealDetailView`: ingredients and recipe.
- [ ] Reuse existing portion confirmation components where possible.
- [x] Use the current design system tokens.
- [ ] Add polished empty/error states:
  - [ ] no matching meals
  - [ ] AI unavailable
  - [ ] free quota exhausted
  - [ ] invalid calorie target

## Localization

- [x] Add strings for all app languages.
- [ ] Localize:
- [ ] Add Meal Kuchnia Oli block
  - [ ] target calorie screen
  - [ ] suggestions list
  - [ ] detail page
  - [ ] paywall trigger copy
  - [ ] errors and empty states
  - [ ] cuisine names
  - [ ] diet/preference chips
- [ ] Ensure library entries have localized names for all supported languages.

## Storage

- [ ] Add model or seed format for dish-library entries.
- [ ] Add model or seed format for product-library entries.
- [ ] Add migration if stored in SwiftData.
- [ ] Prefer seeded JSON plus import service if the catalog is large.
- [ ] Keep user-created dishes separate from global library.

## Tests

- [ ] Unit-test local-day quota reset for Kuchnia Oli.
- [ ] Unit-test free vs premium quota behavior.
- [ ] Unit-test calorie scaling.
- [ ] Unit-test local library matching.
- [ ] Unit-test AI response validation.
- [ ] Unit-test localization availability for Kuchnia Oli strings.
- [ ] Add at least one UI smoke test for opening Kuchnia Oli from Add Meal.

## Implementation Order

- [x] Step 1: add quota kind, entitlement field, paywall trigger, and tests.
- [x] Step 2: replace Add Meal "Co zapisujemy?" block with Kuchnia Oli teaser block.
- [x] Step 3: build target-calorie screen and navigation.
- [x] Step 4: add local dish/product library seed format.
- [x] Step 5: import/generate 1000+ classic meals/products with cuisine coverage.
- [x] Step 6: implement local matching and calorie scaling.
- [x] Step 7: build suggestions list and detail page.
- [x] Step 8: wire "Add to diary" through existing portion confirmation.
- [ ] Step 9: add Worker AI endpoint and app client.
- [ ] Step 10: add caching and AI fallback.
- [x] Step 11: localize first-version UI strings.
- [x] Step 12: run build and install on iPhone for design review.
