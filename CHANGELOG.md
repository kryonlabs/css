# Changelog

## Unreleased

- Lengths take em, vw and vh and calc(), min(), max() and clamp(): static ones fold while the sheet is read, viewport ones resolve at install and packs keep them; CssSheetSameMedia reports a change when a new viewport changes an active length. var() fallbacks may nest one var(), and var(--kryon-NAME) reads the installed theme palette.

- Lower margin, min/max width, max height, overflow and text-align to native box styles. Packs use one rule layout; a pack in an older layout is refused as stale.

- Resolve flex direction, wrapping, sizing, gaps and alignment from stylesheets and compiled packs.

- Add recoverable native stylesheet diagnostics and `css_tool check --strict`
  with source locations for rejected and browser-only CSS.

- Resolve native viewport-width media queries and responsive equal-width grid
  tracks in parsed sheets and compiled packs while preserving browser export.

- Align the native stylesheet runtime with Kryon size serialization so compiled
  width and height rules survive widget transport.

- Added opt-in native CSS transitions and keyframes for parsed and compiled
  stylesheets, with browser motion declarations preserved in CSS export.

- Added native `color-mix(in srgb, ...)` for two literal color stops with
  browser-compatible percentages and premultiplied alpha.
- Added native `prefers-reduced-motion` queries through `CssEnvironment`,
  including compiled packs and browser-controlled web export.
- Added native CSS gaps and axis padding for `Row` and `Column`, plus font
  weight, font style, signed letter spacing and typed line height for text.
- Added `hwb()` colors, hue angle units and `min-block-size` for horizontal
  layouts. Opacity is clamped after custom properties resolve.
- Updated browser export for Kryon DOM selection and verified style IDs,
  computed styles and widget identity in the production DOM runner.
- Retired the KSS migration tool and legacy system-style loader. Applications
  use CSS sheets and the compiled CSS style packs.
