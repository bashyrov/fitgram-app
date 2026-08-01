# Mealgram revamp — full task list

Source: user request 2026-05-22.
Goal: international launch (90% English, world-wide focus).

## A. Strategic pivot
1. Drop "Polish-only" framing — global audience, Polish cuisine is one of many.
2. Quick DB grows from 160 PL dishes to **3000+ international foods**.
3. Quick DB + scanner + recipes use international cuisine.
4. Cuisine names + categories must be localised to the active language.

## B. UX redesign
5. **Add** menu: replace native action sheet with a custom modal styled to the app — minimal, clear, dropdown-style.
6. New screenshots needed:
   - Add menu open (the full dropdown list)
   - Week (already shipped — keep refreshed)
   - "My goals + daily targets" combined on a single screen
7. All screenshots in EN only, dropped into `~/Desktop/mealgram-screenshots-all/en/`.
8. Test data must be present everywhere on screenshots.

## C. Translation bugs (UK was selected, PL was shown)
9. Profile top block: `Schudnąć …`
10. My goals: `0.5 kg / tydz`, `z obecnej wagi`
11. Macros: `Białko`, `Tłuszcz`, `Węgle`
12. Premium teaser: `Wypróbuj za darmo…`
13. Activity levels: PL descriptions while UI was UK
14. Goal-speed: `Spokojnie / Szybkie` PL descriptions
15. Ola plan in onboarding — PL
16. Daily targets (protein/carbs/fat) — PL
17. Onboarding: missing female icon
18. Profile: missing female icon

## D. Error UX
19. No raw error details to user — generic message + buttons only.

## E. Profile
20. Top block: reduce height.

## F. Account
21. Email is not surfaced anywhere — make sure it's fetched + visible.
22. Onboarding must collect username + display name.

## G. Onboarding flow
23. First screen: `Start` button covers the "no guilt" block — fix layout.
24. Remove the "skip onboarding" affordance.
25. Activity-level: stop showing PL descriptions on other languages.
26. Goal-speed: same — localise `Spokojnie / Szybkie` etc.
27. Goal date layout: button covers the date row.
28. Demo scan screen: make it a real one-shot demo (free, no save to today's stats).
29. Onboarding Ola plan: today it's static — must rotate per user (real AI request).
30. Onboarding Ola plan + daily target block need translation + nicer design.

## H. Lifecycle bug
31. Adding a meal from Quick DB right after onboarding does not appear in stats until app relaunch.

## I. Branding / animation
32. Audit logos — only the leaf is allowed; remove any third-party logos.
33. Every long-running screen must show a delightful (but lightweight) loading animation.
34. Cold-start splash: animated "Mealgram" wordmark in Agbalumo Regular on a white background.

## J. Final polish
35. After everything: full translation audit — every screen, every word.
36. Then a full pre-deploy audit / bug sweep.
37. Write back a concise plan of what was completed.

## K. Logistics
38. Copy `/tmp/mealgram-shots/progress-en.png` + `/tmp/mealgram-shots/watch-en.png` (and any new ones) into `~/Desktop/mealgram-screenshots-all/en/` so the user does not have to hunt for them.
