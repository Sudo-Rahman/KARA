# KARA — Design QA

Date: 21 July 2026  
Viewport: iPhone 17 Pro, iOS 27.0, French locale

## Sources and comparison evidence

- Dashboard reference: `/var/folders/3g/v5w6q1p118d7w70kqz36fpjw0000gn/T/codex-clipboard-5ea70900-b19a-479c-b2fd-8c63e497c518.png`
- Inventory/detail/documents reference: `/Users/sr-71/Downloads/ChatGPT Image 4 juil. 2026, 18_07_30 (2).png`
- Final dashboard: `/tmp/kara-vault-final.png`
- Final dashboard comparison: `/tmp/kara-dashboard-comparison-final.png`
- Final flow comparison: `/tmp/kara-flow-comparison-final.png`
- Accessibility Dynamic Type check: `/tmp/kara-vault-final-dynamic-type-fixed.png`

Both final comparison images place the supplied references and the running implementation in the same visual input.

## Fidelity and product fit

- The information architecture from the references is preserved: headline metrics, holdings composition, portfolio history, primary actions, live gold, inventory, asset detail, and linked documents.
- The implementation deliberately continues KARA's existing black, deep-cobalt, frosted-glass, and gold visual language instead of copying the light AURIA styling.
- Hierarchy, spacing, radii, iconography, contrast, and numerical emphasis are consistent across the new journey.
- The inventory and linked-document screens stay inside the requested NavigationStack journey; no unrelated global document destination was introduced.
- Dynamic metal rows are data-driven, so only metals present in the portfolio appear.

## Interaction and state coverage

- Privacy toggle masks portfolio values and quantities across the journey while keeping public spot prices visible.
- Inventory card navigation, search, filtering, sorting, asset detail, full edit, linked-document preview/share/rename/delete, and integer-quantity sale simulation are wired.
- Empty, populated, loading, cached, unavailable-market, partial-valuation, and complete-valuation states are represented.
- Live and historical market values come from the production API with decimal-safe calculations and cache fallback; no displayed portfolio statistic is hard-coded.

## Accessibility and resilience

- VoiceOver labels and stable accessibility identifiers cover the core journey.
- Privacy state persists and the app-switcher privacy shield protects sensitive content.
- Accessibility Dynamic Type switches dense metric rows and coverage metadata to vertical layouts; the final extra-extra-large check shows no horizontal clipping.
- French and English localization catalogs validate as JSON.

## Verification

- Unit tests: 115 passed, 0 failed, 0 skipped.
- Vault inventory/detail/edit/documents UI journey: passed.
- Privacy and integer sale-simulation UI journey: passed.
- Debug and Release simulator builds: passed.
- `git diff --check`: passed.

Result: passed
