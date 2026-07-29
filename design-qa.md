# Design QA — Performance

- Source visual truth: `/var/folders/3g/v5w6q1p118d7w70kqz36fpjw0000gn/T/codex-clipboard-cf85a04a-539a-41cf-8834-69997ab09de8.png`
- Implementation captures:
  - `/Users/sr-71/.codex/visualizations/2026/07/29/019fad10-98ac-7921-a8b2-816ddeaf6c71/kara-performance-top.png`
  - `/Users/sr-71/.codex/visualizations/2026/07/29/019fad10-98ac-7921-a8b2-816ddeaf6c71/kara-performance-chart.png`
- Viewport: native iPhone 17 Pro simulator, iOS 27.0, 402 × 874 pt at 3×.
- Pixel dimensions: source 762 × 1682 px including its device frame; implementation 1206 × 2622 px. CSS size and deviceScaleFactor are not applicable to this native SwiftUI build.
- Density normalization: comparison used the app-owned portrait content region and proportional layout rather than a pixel diff. The source is a framed light-theme concept on a different device ratio, while the requested implementation intentionally remains in KARA's native dark theme and design system.
- State: French locale, seeded five-asset vault, complete acquisition-cost coverage, one-year period for captures.

## Full-view comparison evidence

The implementation preserves the source's core composition: a dedicated Performance title, a ranked latent-gain card with horizontal progress bars, and a grouped vertical bar chart by asset category. It adds a compact financial summary above the ranking so users see total latent gain, return, comparable current value, acquisition cost, selected-period change, and coverage before interpreting contributors.

The grouped chart intentionally compares current analyzed value with acquisition cost. Comparing current value with spot would be redundant in KARA because the current estimate is itself derived from spot prices.

## Focused-region comparison evidence

- Ranking: five asset rows, right-aligned signed gains, proportional gold bars, signed return percentages, and neutral tracks are readable and preserve the visual rhythm of the source.
- Category chart: three leading categories, paired gold/cobalt bars, compact euro axis, localized category labels, legend, and valuation date remain legible at the native viewport.
- Summary: the strongest hierarchy is assigned to latent gain; supporting values and data coverage remain visibly secondary.

## Findings

No actionable P0, P1, or P2 differences remain.

- [P3] The summary card moves the ranking below the first viewport compared with the source.
  - Location: top of `AnalysisPerformanceView`.
  - Evidence: the source begins with ranking; the implementation begins with latent gain and comparable-value KPIs.
  - Impact: one extra scroll is required to see all five contributors, but the most decision-useful portfolio result is available sooner.
  - Classification: intentional product improvement requested by the brief; no fix required.

## Required fidelity surfaces

- Fonts and typography: KARA's Geologica display hierarchy and native supporting text are consistent, readable, and free of truncation in the captured state.
- Spacing and layout rhythm: 16 pt page margins, 24 pt section gaps, large card padding, consistent radii, and sufficient bottom clearance keep content separate from the floating tab bar.
- Colors and tokens: the existing void/surface/gold/cobalt system is applied consistently; green and red are reserved for signed performance states.
- Image quality and asset fidelity: the target contains no app-owned raster imagery needed by this screen. SF Symbols are used for standard informational and navigation icons.
- Copy and content: French labels distinguish period change from acquisition-based latent gain, state coverage explicitly, and avoid presenting the screen as advice or a forecast.
- Accessibility and interactions: sensitive amounts remain wrapped by the privacy component; navigation, the period picker, scrolling, and the destination route were exercised successfully.

## Comparison history

- Iteration 1: combined source/top/lower comparison found no P0/P1/P2 visual issue. No visual fix loop was required.

## Implementation checklist

- [x] Add the six-month period to analytics and the segmented picker.
- [x] Replace the duplicated evolution destination with the Performance screen.
- [x] Add acquisition-based summary and explicit coverage.
- [x] Add a five-asset latent-gain ranking with horizontal bars.
- [x] Add a three-category current-value versus acquisition-cost chart.
- [x] Verify the six-month selection persists into the destination.
- [x] Verify the route and primary cards with UI automation.

## Follow-up polish

- [P3] Add a dedicated accessibility-size visual snapshot if the team starts maintaining a Dynamic Type screenshot matrix.

final result: passed
