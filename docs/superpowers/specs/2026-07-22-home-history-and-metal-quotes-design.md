# KARA Home History and Metal Quotes

## Objective

Make the home dashboard's portfolio history immediately understandable and expand the live-market card from gold only to all four supported precious metals. Remove redundant or confusing status copy while preserving the existing visual language, privacy behavior, localization, accessibility, and pull-to-refresh flow.

## Portfolio history controls

- Add a native segmented period picker to the portfolio-history card with four options: `3 months`, `6 months`, `12 months`, and `All`.
- Select `12 months` whenever the home dashboard is created.
- Keep the selected period local to the dashboard; it does not need persistence across launches.
- Remove the gain percentage from the history-card header. That percentage describes gain since acquisition, not change over the selected chart period, and remains available in the dedicated unrealized-gain metric.
- Keep the existing insufficient-data and unknown-acquisition-date messages, except where wording changes are explicitly specified below.

## History range and data semantics

- Build portfolio history from the earliest known acquisition date through the live valuation point.
- For `All`, begin the visible chart domain at the later of (a) the first day of the month containing the earliest known acquisition and (b) the first available source-backed month.
- If no asset has a known acquisition date, let `All` begin at the first available source-backed month and retain the unknown-date explanation.
- For `3 months`, `6 months`, and `12 months`, include the current calendar month plus the preceding 2, 5, or 11 calendar months respectively. Begin the visible domain on the first day of that initial month and end it at the live valuation date.
- Include an asset in historical portfolio value only on and after its acquisition date, following the existing acquisition-aware valuation behavior.
- Continue treating assets without an acquisition date as held throughout the visible period and retain the explanatory note for that case.
- Never synthesize market values outside the source dataset. EUR monthly data currently begins in January 1999; if the earliest acquisition predates coverage, `All` begins at that first available source-backed month without a misleading empty interval.
- Filter the full history locally for the selected period rather than recalculating valuation every time the user changes the segmented control.

## Chart axis presentation

- Pin the X-axis domain to the selected period so Swift Charts does not introduce a visually unexplained leading gap.
- For the three bounded periods, show abbreviated month labels. Include the year on the first visible label and whenever the year changes.
- For `All`, use legible annual ticks whose density adapts to the total span.
- Preserve locale-aware date formatting, monospaced numeric currency labels, the existing line/area styling, the current-point marker, and privacy concealment.
- Update the chart accessibility description so it names the selected period instead of always saying "the last twelve months."

## Precious-metal quote selector

- Rename the market card from `Live gold price` to `Metal prices` in English and from `Cours de l’or en direct` to `Cours des métaux` in French.
- Add a native segmented metal picker with `Au`, `Ag`, `Pt`, and `Pd` segments for gold, silver, platinum, and palladium.
- Select gold whenever the home dashboard is created.
- Show all four choices regardless of which metals the user owns; this card represents public market data, not portfolio composition.
- Give every abbreviated segment an explicit localized accessibility label using the full metal name.
- Update the full metal name, price per gram, price per troy ounce, timestamp, and availability state together when the selection changes.
- Use a short state-change transition for the quote content and respect Reduce Motion.

## Quote loading and status

- Change the dashboard input from one optional gold quote to the set of available EUR quotes keyed by metal.
- Always request EUR spot quotes for all four supported metals during initial load and refresh, independently of the assets in the vault.
- Remove the green `Updated` / `Actualisé` pill. A successful quote is already explained by its source timestamp.
- Retain the cached-data state only when it is true, presenting `Saved quote` / `Cours enregistré` discreetly on the timestamp line rather than as a prominent trailing chip.
- If the selected metal has no quote, show the existing unavailable state and retry action for that metal while keeping the selector usable so other available metals remain accessible.
- Remove the sentence `No daily change is displayed without a source-backed figure.` and its French equivalent entirely. Do not replace it with other explanatory copy.
- Keep the refreshing indicator and pull-to-refresh behavior.

## Localization and accessibility

- Add or update English and French strings for the period labels, `All`, the generic market-card title, full metal names where required, cached timestamp presentation, and dynamic chart accessibility descriptions.
- Keep control hit areas at least 44 points and support Dynamic Type without clipping. If a four-item segmented control cannot fit at accessibility text sizes, allow the controls to use their native adaptive presentation without truncating meaningful labels.
- Keep values compatible with the existing privacy-concealment wrapper and VoiceOver behavior.
- Preserve Dark Mode, increased contrast, Reduce Transparency, and Reduce Motion behavior.

## Implementation boundaries

- Limit production changes to the home dashboard, its market-data inputs, portfolio-history generation/filtering, localization, and directly relevant tests.
- Do not change persistence, asset creation, inventory navigation, sale simulation, external data sources, or unrelated design-system components.
- Preserve the current monthly source data and do not infer daily performance from monthly observations or spot quotes.

## Verification

- Add unit coverage proving that full history reaches the earliest known acquisition when source data exists and never includes assets before their acquisition date.
- Add coverage for bounded 3-, 6-, and 12-month filtering and the first-day-of-month visible domain calculation.
- Add coverage for acquisitions before the January 1999 EUR boundary and assets with unknown acquisition dates.
- Verify that home loading requests EUR quotes for gold, silver, platinum, and palladium.
- Verify that every metal can be selected, displays its own values and timestamp, and handles an unavailable quote without disabling the other choices.
- Verify that `12 months` and gold are the initial selections whenever the dashboard is created.
- Verify in the iOS Simulator at standard and accessibility Dynamic Type sizes, including normal, cached, refreshing, unavailable, privacy-concealed, and Reduce Motion states.
