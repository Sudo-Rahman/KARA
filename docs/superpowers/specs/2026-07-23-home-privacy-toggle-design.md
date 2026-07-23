# Home Privacy Toggle Design

## Objective

Make the home dashboard the only place where users can change whether sensitive values are concealed. The concealment preference remains global, persistent, and effective on every screen.

## User Interface

- Replace the decorative `sparkles` icon in the home dashboard's "Estimated value" card with the existing privacy control.
- Preserve the current 44-by-44 circular gold-tinted presentation used by the decorative icon.
- Display `eye.fill` when sensitive values are visible and `eye.slash.fill` when they are concealed.
- Keep the existing localized accessibility label and hint, and expose a stable home-specific accessibility identifier.
- Remove the privacy control from every navigation or modal toolbar, including the home title bar, inventory, asset detail, asset documents, and sale simulation.
- Do not add the control to empty-home state content: the estimated-value card only exists when the portfolio contains assets.

## State and Data Flow

`PrivacyPreferences` remains the single environment-provided source of truth. The home card button calls its existing `toggle()` method. `SensitiveValue` continues reading the same preference, so changing it on the home dashboard immediately conceals or reveals sensitive values throughout the application and persists across launches.

No screen receives a local privacy state, and no sensitive-value rendering behavior changes.

## Component Changes

- Generalize or rename `PrivacyToolbarButton` so its implementation no longer implies toolbar-only use.
- Keep the circular 44-point styling inside the reusable control so the full visible circle is the button's interactive and accessible area.
- Delete all non-home call sites.

## Verification

- Update UI-test expectations so `privacy.toggle` is present only on the populated home dashboard.
- Verify the toggle is absent from inventory, asset detail, documents, and sale simulation toolbars.
- Verify activating the home control changes the global preference and that sensitive values remain concealed after navigating to those screens.
- Run the relevant privacy unit tests, UI tests where available, and a build of the iOS target.

## Out of Scope

- Changing which values are considered sensitive.
- Changing the blur effect, persistence key, or inactive-app privacy shield.
- Adding another privacy control in settings or on the empty dashboard.
