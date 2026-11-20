# Kryon CSS

Kryon applications are styled with a subset of CSS. This package parses
`.css` sheets into Kryon's style table, compiles style packs into tables apps
load without parsing, formats sheets, exports them to browser CSS for
Kryon's document host. It ships the optional classic, lightfield and material
packs in `styles/`. The same table drives every
Kryon backend: desktop, console, Android, the web canvas and DOM hosts, and
apps built through the C, C++ and Go targets.

## Use it

```sh
ziran add https://github.com/kryonlabs/css.git
```

The Kryon and Ziran revisions for this package are pinned in
[ziran.toml](ziran.toml) and [ziran.lock](ziran.lock). Use the same Kryon
source URL and revision in the app so the stylesheet and widgets share
one Kryon instance.

```zi
using Styles :: #import "css/Css";
#import "kryon/Theme"

sheet: CssSheet;

Start :: () {
    if !InstallDefaultTheme(false) { return }
    if CssSheetParse(*sheet, app_css, "app.css", CssNoImports) {
        CssSheetInstall(*sheet, CssDefaultEnvironment(), null)
    }
}
```

A sheet is parsed whole or not at all: `CssSheetParse` returns false with a
diagnostic such as `unknown property 'colr' at app.css:2:3`
(`CssSheetDiagnostic`). `CssSheetInstall` resolves `var()` for an
environment and installs the rules and color custom properties together; on
failure the previous style stays. `CssSheetBuild` fills a `StyleRules` table
without installing it, and `CssSheetToken` reads a custom property's value.
`CssOverrideColor` and `CssOverrideLength` let a host override custom
properties (`--accent`, for example) for one install. A canonical Kryon theme
is installed separately; no style pack is restored automatically.

Imports go through a resolver you pass: `(name: string) -> CssImportAnswer`.
Hosts without imports pass `CssNoImports`.

## The subset

Each selector can combine a widget type (`Button`, `TextField`, `Row`,
`Column`, `App`, `*`),
one class (`.primary`), one ID (`#save`; set `props.id` to `StyleId("save")`),
Kryon attributes (`[role=Label]`, `[tone=Accent]`, `[emphasis=Soft]`,
`[size=Small]`, `[state=normal]`) and one state pseudo-class:
`:hover`, `:active`, `:focus`, `:focus-visible`, `:disabled`, `:selected`,
`:checked` or `:loading`, in comma lists. Combinators and nesting are outside
the subset.

Properties: `color`, `background` (a color or a two-stop
`linear-gradient`), `background-color`, `border`, `border-color`,
`border-width`, `border-style` (`solid` or `none`), `border-radius`,
`outline-color`, `opacity` (number or percentage), `padding` (opposite sides
must match),
`padding-inline`, `padding-block`, `gap`, `row-gap`, `column-gap`,
`font-size`, `font-family`, `font-weight`, `font-style`,
`letter-spacing`, `min-height`, `min-block-size`, `line-height`,
`translate`, `-kryon-material` (`lightfield`, `flat`, `glass`),
`-kryon-icon-size`, `-kryon-font-role` (`inherit`, `control`, `body`,
`heading`, `code`), `-kryon-elevation` (`none`, `rest`, `raised`, `floating`),
`-kryon-motion-duration`, `-kryon-motion-multiplier`,
`-kryon-motion-easing` (`inherit`, `standard`, `linear`, `instant`) and
`-kryon-motion-reduced` (`reduce`, `no-preference`). Document layout properties
(`width`, `margin`, `display`, `transition` and the like) are kept for the web
document host and skipped by native hosts. Each native widget uses the fields
its paint and layout implement:

- `gap` takes one value for both axes or two values in row, column order.
  `row-gap` and `column-gap` cascade independently. Gaps take `normal`
  (zero in native layout) or a nonnegative `px` or `rem` length. A `Row`
  uses its column gap and a `Column` uses its row gap. Controls that use a
  uniform gap read the first `gap` value.
- Native `Text`, `Heading` and `ParagraphText` read `font-weight`,
  `font-style` and `letter-spacing`. Weight takes `normal` (400), `bold` (700)
  or a number from 1 to 1000, rounded to a whole number for native fonts.
  Style takes `normal`, `italic` or `oblique` without an angle. Letter spacing
  takes `normal` (zero) or a signed `px` or `rem` length.
- Text and Button accept `line-height: normal`, a nonnegative unitless
  factor or percentage of font size, or a nonnegative absolute `px` or `rem`
  length.

`min-block-size` and
`min-height` set the same field in horizontal native layout, with the last
declaration breaking ties at equal priority. Use a nonnegative `px` or `rem`
length, or zero, for either property. A zero value lets Button use its
default minimum. Opacity clamps to `0`–`1` after resolving custom properties.

Values: hex, named, `rgb()`, `rgba()`, `hsl()`, `hsla()` and `hwb()` colors;
`px` and `rem` (16px) lengths; `s` and `ms` durations; `var(--name, fallback)`.
Hue accepts a number in degrees or `deg`, `grad`, `rad` or `turn`. Write
`hwb(hue white% black% / alpha)` with spaces between channels and optional
alpha as a number or percentage. Colors are stored as 8-bit RGBA.
`em` and `%` lengths are errors, because Kryon has no inherited font size
or containing block. Custom properties are declared in `:root`, keep the type
of their declared value, and cannot be used where another kind is required.

At-rules: `@import` (before other rules), `@layer` statements and blocks,
`@media` with `prefers-color-scheme`, `prefers-contrast`, `pointer`,
`prefers-reduced-motion`, `min-width` and `max-width`, plus Kryon's
`-kryon-theme`, `-kryon-density`, `-kryon-pointer` and `-kryon-platform`
features, and `@keyframes`.
`!important`, escapes and `//` comments are errors.

Rules rank by layer (unlayered rules last), then Kryon's specificity, then
source order. Kryon's specificity counts a widget type 1, each attribute 10,
a class 20 and an ID 200; states add nothing, because a widget is in one
state at a time (disabled, loading, pressed, hovered, selected, focused, in
that order of precedence).

## Port HTML styles to native widgets

Choose the Kryon widget based on what the HTML element does, then use its
widget name or a class in the stylesheet.

| HTML | Kryon CSS selector | Native styling examples |
| --- | --- | --- |
| `<button>` | `Button` | Fill, text color, border, radius, padding, font size and minimum height |
| `<input type="text">` | `TextField` | Fill, text color, border, radius, inline padding and font size |
| `<textarea>` | `TextArea` | Fill, border, padding and font size |
| `<a>` | `Link` | Text color, font size and opacity |
| `<h1>`–`<h6>`, `<p>` | `Heading`, `ParagraphText` | Text color, size, weight, style, letter spacing and line height |
| `<main>`, `<section>` | `Page`, `Section` | Theme, paint and spacing where the widget exposes them |
| Horizontal or vertical group | `Row`, `Column` | Axis gaps and symmetric inline/block padding |

For `<button id="save" class="primary">`, set the `Button` props `id` to
`StyleId("save")` and `class_name` to `StyleClass("primary")`. Let Kryon
measure the button by leaving `props.bounds.height` at zero.

```css
:root {
  --accent: hwb(.6turn 10% 20%);
}

Button.primary#save {
  background: var(--accent);
  color: white;
  min-block-size: 2.75rem;
  padding: 8px 16px;
  border-radius: 6px;
}

Button.primary#save:hover {
  opacity: 85%;
}

Row.actions {
  gap: 4px 12px;
  padding: 8px 16px;
}

Heading.title {
  font-weight: 650;
  line-height: 125%;
  letter-spacing: -0.5px;
}
```

The example sets a 44-unit minimum height and 8-unit vertical and 16-unit
horizontal padding. Use Kryon layout APIs for native flex/grid layout and
margins. Text emphasis, alignment and wrapping are widget props where available.

## Style packs

`styles/NAME.css` is compiled into `src/style_pack_NAME.zi`, a table of
words `CssSheetLoad(*sheet, StylePackNAME())` appends without parsing. Import
the selected module, such as `#import "css/style_pack_classic"`, and load its
`StylePackClassic()` result explicitly; no pack is automatic or default.
After editing a pack, run `make style-packs` and commit the module with it;
`make style-pack-check` fails when a module no longer matches its CSS or the
CSS is not formatted.

## Formatting

`CssFormat(source, output)` writes one declaration per line with two-space
indentation. It refuses a sheet that does not parse, and checks that the
formatted sheet parses to the same rules. `make format FILES="a.css"` runs
it on files.

## Browser CSS

`ExportCSS(source, path, environment, output)` writes CSS for Kryon's DOM
host. Selectors are scoped under `#kryon-dom-root` and matched against the
`data-kryon-widget`, `data-kryon-class`, `data-kryon-id` and ARIA attributes
the host writes; custom properties go on the root, `-kryon-*` declarations are
dropped, environment media queries are decided for `environment`, and
viewport queries stay for the browser. Every selector is wrapped in
`:where()` and rules are written in Kryon's priority order, so the browser
ranks them as native hosts do. Attribute selectors and unresolved imports
are refused with a message, never exported in part. `StyleClass(name)`
returns the class ID Kryon widget props take. `make export IN=app.css
OUT=browser.css` runs the same exporter from the command line.

## Develop

`make check` runs the behavior tests, the conformance test, the style pack
check, the production Kryon DOM test and the fuzzer. The DOM test uses
Python 3.11 or newer and headless Chromium. It resolves Kryon and Ziran
through the configured `ZIRAN` executable. Set `CSS_DOM_SOURCE` to the CSS
checkout when testing its working sources from a separate dependency graph.
The conformance test (`tests/css_conformance.sh`)
builds each pack with an app sheet over it and requires the same digest of
the rule table and every resolved widget style from the C program, a C++
host, the Go target, a ZX bundle and, when a phone is on adb and the NDK is
installed, an Android build. It then checks the browser export of the app
sheet value by value in headless Chromium. `make fuzz FUZZ_SEED=N
FUZZ_COUNT=M` runs generated and damaged sheets under AddressSanitizer and
UndefinedBehaviorSanitizer; a failing sheet is kept in `build/css-fuzz/`.

To test against local compiler and Kryon checkouts, put this in an ignored
`ziran.local.toml`:

```toml
[overrides]
ziran = "../../../ziranlang/ziran"
kryon = "../../kryon"
```
