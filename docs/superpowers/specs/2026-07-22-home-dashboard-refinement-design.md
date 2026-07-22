# KARA Home Dashboard Refinement

## Objective

Simplify the home dashboard, restore a clear native navigation hierarchy, and make its Liquid Glass surfaces feel intentional and responsive. Preserve the current data, card order, routes, localization, accessibility support, and privacy preference behavior.

## Navigation and wording

- Remove the marketing introduction: the private-vault eyebrow, portfolio headline, and explanatory subtitle.
- Present `Kara` as a centered, gold-tinted title directly inside the navigation bar.
- Keep the title inline and stable while the user scrolls.
- Keep the privacy control in the trailing navigation-bar position.
- Render the privacy control as a flat, gold-tinted eye icon without a Liquid Glass background or grey circular plate.

## Cards and interaction

- Keep the existing Liquid Glass card visual language and card order.
- Give every glass card subtle touch-driven visual feedback.
- Compose each card border inside the same rendered surface as its interactive Liquid Glass effect, so the border follows the system-managed press enlargement exactly.
- Preserve navigation only for cards and rows that already have a destination; informational cards must not invent new routes or accessibility button semantics.
- Keep card shapes, borders, spacing, and interaction feedback consistent.
- Make the unrealized-gain and inventory metric cards equal in height at standard Dynamic Type sizes.
- Continue stacking those metric cards vertically for accessibility Dynamic Type sizes.

## Privacy presentation

- Conceal sensitive values by blurring and fading the rendered value itself.
- Do not replace values with glass rectangles, placeholder bars, or an opaque card-like mask.
- Add only a restrained diffuse halo if needed to keep the concealed state polished.
- Keep concealed content inaccessible to VoiceOver and retain the current localized masked-value label.
- Respect Reduce Transparency and Reduce Motion settings.

## Actions

- Give `Ajouter un actif` and `Simuler une vente` the same minimum height, capsule geometry, label alignment, and press response.
- Preserve a clear hierarchy: the add action remains primary and the simulation action remains secondary.
- Preserve disabled behavior for sale simulation when no valued record exists.

## Asset artwork

- Display user photos and bundled category artwork edge-to-edge inside their artwork frame.
- Use aspect-fill with centered cropping so square source images do not leave white or empty margins.
- Keep the current rounded clipping, border, sizing, and accessibility behavior.

## Implementation boundaries

- Limit changes to the home dashboard and shared design-system components directly responsible for these visuals.
- Do not change valuation logic, persistence, market-data loading, navigation destinations, or unrelated asset-creation work already present in the worktree.
- Prefer native SwiftUI toolbar composition and native iOS 26 Liquid Glass interaction APIs.

## Verification

- Build the KARA scheme without launching the app.
- Leave visual inspection of the title, cards, privacy state, actions, and artwork to the user on a physical iPhone.
- Verify both visible and concealed privacy modes.
- Verify equal metric-card and action-button heights visually.
- Run the unit-test target only; do not execute UI tests.
