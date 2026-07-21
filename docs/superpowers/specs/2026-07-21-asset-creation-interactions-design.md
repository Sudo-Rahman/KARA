# Asset Creation Interaction Improvements

## Objective

Make the six-step asset creation flow feel continuous and predictable by keeping its navigation chrome stable, making keyboard dismissal reliable, letting horizontal carousels clip at the physical screen edges, and replacing saved seller and storage chips with searchable combobox inputs.

## Scope

This change is limited to the iOS asset creation flow. It preserves the existing six steps, draft model, validation rules, cancellation confirmation, persistence behavior, and native `NavigationStack` history.

## Persistent Flow Header

`AssetCreationFlowView` will own one header outside the changing navigation destination. The header contains:

- a back button when the current step is not the first step;
- the localized title for the current step;
- the existing cancel button;
- the localized progress label and six progress segments.

Individual step views will no longer install a navigation title, cancel toolbar item, or top progress safe-area bar. The router remains the single source of truth for the current step. Back invokes `router.goBack()`, and cancel keeps the existing confirmation behavior.

The back and cancel icons use the same cobalt foreground and matching circular treatment. When the step changes, the progress number uses a numeric content transition and the segments animate between inactive and completed colors. The title may cross-fade with the same short control-response animation. All nonessential motion is disabled when Reduce Motion is enabled.

The page transition remains native and happens underneath the persistent header. The bottom action area remains owned by each step because its label, enabled state, and secondary content vary by page.

## Keyboard Dismissal

Editable steps retain their narrow, local `FocusState` ownership. `AssetStepScaffold` gains an optional keyboard-dismiss action supplied by editable screens.

- A tap in a noninteractive part of the page clears the local focus.
- Beginning a vertical scroll dismisses the keyboard immediately.
- Tapping another input transfers focus normally.
- Tapping a button or picker still performs that control's action.
- Advancing to another step clears focus before routing.

This behavior applies equally to text, decimal, and number keyboards.

## Edge-to-Edge Horizontal Carousels

The classification metal and preset carousels expand their viewport through the scaffold's horizontal page padding so offscreen content clips at the physical screen edge. Scroll content margins preserve the initial alignment of the first item with the page's text and section headings.

Horizontal controls embedded inside a contained field surface, such as gold-purity shortcuts, keep clipping to that surface because their container boundary is intentional.

## Searchable Saved-Value Combobox

Seller and storage location use one reusable SwiftUI component with the following behavior:

1. The control looks and edits like the existing text input.
2. Focusing the input reveals an inline suggestion panel directly beneath it.
3. Suggestions are filtered against the typed text without case or diacritic sensitivity.
4. An empty query shows the most recently used values, using the existing SwiftData query order.
5. The current exact value is marked with a checkmark.
6. Selecting a suggestion replaces the input value, clears focus, and closes the panel.
7. Tapping elsewhere or scrolling closes the keyboard and panel.
8. Free text remains valid. The existing save path persists a new seller or storage location, so it appears in future suggestions after the asset is saved.

The suggestion panel is part of the scroll content rather than a system `Menu` or compact-device popover. This keeps search and selection visible above the keyboard and avoids adaptive sheet presentation on iPhone. Its appearance follows the current dark surfaces, cobalt selection color, and spacing tokens.

## State and Component Boundaries

- `AssetCreationFlowView` owns persistent navigation chrome and current-step animation.
- `AssetCreationRouter` remains responsible only for ordered navigation state.
- `AssetStepScaffold` owns shared scrolling, bottom safe-area content, and the optional background-dismiss hook.
- Editable step views own their focus enum and clear it through the scaffold hook.
- The combobox owns only transient presentation and filtering state; its text remains a binding to `AssetDraft`.

No new view model or global keyboard singleton is introduced.

## Accessibility and Localization

The existing `asset-flow.progress` identifier and localized progress label remain intact. Back and cancel buttons receive explicit localized labels and identifiers. The combobox exposes its text field, suggestion list, and selected suggestion to VoiceOver; suggestion rows use button semantics and selected traits. Existing French and English strings are reused where possible, with new strings added for the suggestion accessibility affordance only if needed.

## Verification

Verification will include:

- unit tests for ordered router back behavior and combobox matching rules;
- UI coverage that progress remains correct while moving forward and backward;
- UI coverage for keyboard dismissal by tap and scroll where XCTest can observe focus or keyboard disappearance reliably;
- UI coverage for filtering/selecting a saved seller or storage location;
- a clean iOS build and the relevant unit/UI test targets;
- visual inspection on an iPhone simulator for header stability, equal icon coloring, animated progress, carousel clipping, and combobox layout with the keyboard visible.

## Non-goals

This change does not redesign the step content, alter validation or save semantics, introduce remote suggestions, allow editing or deleting saved values from the combobox, or replace the existing navigation stack.
