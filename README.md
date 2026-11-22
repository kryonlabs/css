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
ziran add https://git.waozi.xyz/kryonlabs/css.git
```

The Kryon and Ziran revisions for this package are pinned in
[ziran.toml](ziran.toml) and [ziran.lock](ziran.lock). Use the same Kryon
source URL and revision from the manifest in the app so the stylesheet,
widgets, and `kryon/motion` share one Kryon instance.

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

## Check styles for native support

Build the CLI with `make build/tools/css_tool`. Run `build/tools/css_tool check app.css`
to list issues with filename, line, byte column, item name and reason. The command
reports each recoverable issue it encounters, including browser-only declarations
and media conditions. A rejected selector or at-rule skips its entire block.
`build/tools/css_tool check --strict app.css` exits with status 1 if any issue is
reported. Both modes exit with status 1 when the stylesheet cannot be recovered.
The CLI checks the given source and treats imports as empty sheets.

Apps can use `CssSheetParseWithDiagnostics(sheet, source, path, resolve, options)`
from `css/Css` to recover while parsing. Set `options.report` to a `CssIssueSink`
with signature `(context: *void, issue: CssIssue) -> void`. Each issue supplies
its origin, item kind, name, reason and `web_only` flag. Copy any text you need
after the callback returns. Imported issues use the paths from the host's
resolver. Set `options.strict = true` to collect the same issues and reject the
sheet. The ordinary `CssSheetParse` preserves its fail-fast behavior and browser
export support. `CssSheetBuild` and installation still validate values after
resolving custom properties in the chosen environment.

## The subset

Each selector can combine a widget type (`Button`, `TextField`, `Row`,
`Column`, `Grid`, `App`, `*`),
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
`grid-template-columns`,
`font-size`, `font-family`, `font-weight`, `font-style`,
`letter-spacing`, `width`, `height`, `min-height`, `min-block-size`, `line-height`,
`translate`, `-kryon-material` (`lightfield`, `flat`, `glass`),
`-kryon-icon-size`, `-kryon-font-role` (`inherit`, `control`, `body`,
`heading`, `code`), `-kryon-elevation` (`none`, `rest`, `raised`, `floating`),
`-kryon-motion-duration`, `-kryon-motion-multiplier`,
`-kryon-motion-easing` (`inherit`, `standard`, `linear`, `instant`) and
`-kryon-motion-reduced` (`reduce`, `no-preference`). Document layout properties
(`margin`, `display` and the like) are kept for the web
document host and skipped by native hosts. Each native widget uses the fields
its paint and layout implement:

- `gap` takes one value for both axes or two values in row, column order.
  `row-gap` and `column-gap` cascade independently. Gaps take `normal`
  (zero in native layout) or a nonnegative `px` or `rem` length. A `Row`
  uses its column gap and a `Column` uses its row gap. A `Grid` uses both independently.
  Controls that use a uniform gap read the first `gap` value.
- `Row`, `Column` and `Grid` read `width` and `height` as outer sizes, including
  padding. They accept positive `px` or `rem` lengths and `auto`. A positive
  axis in `props.bounds` takes precedence. Otherwise `auto` uses the ordinary
  parent content size, or the measured row height for a grid with declared
  items, and can override an earlier size rule. Other sizing
  values, including zero, percentages, intrinsic keywords, `var()` and
  `calc()`, are browser-only and are skipped by native layout. Browser export
  keeps both sets of values. Native packs accept the native subset.
- `Grid` supports `1fr`, `minmax(0, 1fr)`, `repeat(N, 1fr)`,
  `repeat(N, minmax(0, 1fr))` and `repeat(auto-fit, minmax(LENGTH, 1fr))`.
  `N` is 1–1024 and `LENGTH` is a positive `px` or `rem` length. The
  responsive spelling `min(LENGTH, 100%)` also works as the minimum.
  Other track expressions remain available to browser export. Choose
  `Layout.Grid` in the app frame and declare each item's height and span.
- `Card.Draw` uses stylesheet axis padding for its returned content rectangle.
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

Values: hex, named, `rgb()`, `rgba()`, `hsl()`, `hsla()`, `hwb()` and `color-mix()` colors;
`px` and `rem` (16px) lengths; `s` and `ms` durations; `var(--name, fallback)`.
Hue accepts a number in degrees or `deg`, `grad`, `rad` or `turn`. Write
`hwb(hue white% black% / alpha)` with spaces between channels and optional
alpha as a number or percentage. Colors are stored as 8-bit RGBA.
`em` and `%` lengths are errors, because Kryon has no inherited font size
or containing block. Custom properties are declared in `:root`, keep the type
of their declared value, and cannot be used where another kind is required.

`color-mix(in srgb, <color> [<percentage>], <color> [<percentage>])` mixes
two supported color literals with premultiplied alpha. Write a weight before
or after its stop. Each weight ranges from `0%` to `100%`. Two omitted
weights default to `50%` each, and one omitted weight fills the remainder
to `100%`. Explicit weights are normalized, with a total below `100%`
reducing the resulting alpha. Two zero weights are an error. Literal mixes
can nest up to 16 levels and round to 8-bit RGBA at the end.
Declare the whole mix in `:root` and read it with `var(--name)`, or use a
literal mix as the fallback in `var(--name, color-mix(...))`. Stops and
weights cannot refer to custom properties. Other color spaces, additional
stops, `currentColor` and calculated weights are unsupported.

```css
:root {
  --button-glow: color-mix(in srgb, #2076c0 35%, transparent);
}

Button.primary:hover {
  background-color: var(--button-glow);
}
```

At-rules: `@import` (before other rules), `@layer` statements and blocks,
`@media` with `prefers-color-scheme`, `prefers-contrast`, `pointer`,
`prefers-reduced-motion`, `width`, `min-width` and `max-width`, plus Kryon's
`-kryon-theme`, `-kryon-density`, `-kryon-pointer` and `-kryon-platform`
features, and `@keyframes`.
`!important`, escapes and `//` comments are errors.

Native `prefers-reduced-motion` uses `CssEnvironment.reduced_motion`,
which defaults to `false`. `(prefers-reduced-motion)` and
`(prefers-reduced-motion: reduce)` match `true` and
`(prefers-reduced-motion: no-preference)` matches `false`. Set the field
from your app's motion preference and reinstall the sheet when it changes.
Browser export keeps the media query for the browser to evaluate.

For responsive native grids, set the environment width to your frame's
logical horizontal size. Native width media conditions accept literal `px`,
`rem` or unitless zero. `CssSheetSameMedia` compares which media conditions
match for two environments, so resizing within one breakpoint can reuse
installed styles. Use `CssSheetInstall` if the active styles were replaced
elsewhere or if the sheet or overrides changed.

```zi
env := CssEnvironmentWithViewportWidth(CssDefaultEnvironment(), viewport.width)
if !installed || !CssSheetSameMedia(*sheet, previous, env) {
    installed = CssSheetInstall(*sheet, env, null)
    if installed { previous = env }
}
```

Rules rank by layer (unlayered rules last), then Kryon's specificity, then
source order. Kryon's specificity counts a widget type 1, each attribute 10,
a class 20 and an ID 200; states add nothing, because a widget is in one
state at a time (disabled, loading, pressed, hovered, selected, focused, in
that order of precedence).

## Native stylesheet motion

Use a Kryon checkout that exports `kryon/style_motion` and opt in where you
install the sheet. `CssSheetParse` and `CssSheetLoad` both feed this entry point.
The regular `css/Css` import and `CssSheetInstall` also work for static styles.

```zi
CssMotion :: #import "css/motion";

// After parsing or loading the sheet:
CssMotion.Install(*sheet, env, null)
```

```css
Button.save {
  background-color: #284b90;
  transition: background-color 160ms ease-out 50ms, border-radius 160ms ease-out 50ms;
}

Button.save:hover {
  background-color: #185fbd;
  border-radius: 12px;
}

Button.notice {
  animation: appear 250ms ease-out both;
}

@keyframes appear {
  from { opacity: 0; translate: 0 4px; }
  to { opacity: 1; translate: 0 0; }
}

@media (prefers-reduced-motion: reduce) {
  Button.notice { animation: none; }
}
```

Kryon's retained widgets sample motion during drawing. Pass the app's motion
preference in `env.reduced_motion` when installing. `transition: none` and
`animation: none` clear a matching declaration lower in the cascade.

Native transitions share one duration, delay and timing function per
selector. A comma list can combine properties with identical timing. For
animations, use one named track per selector. Put motion longhands together
in the same rule, where they can also override shorthand values. Both forms
accept `ms` and `s`, signed delays, `linear`, `ease`, `ease-in`, `ease-out`,
`ease-in-out` and `cubic-bezier()`. Animations also support fractional or
infinite repeats, all four directions and all four fill modes.

The native fields are solid background color, text color, border color,
border width, corner radius, opacity and two-axis `translate`. Keyframes
accept `from`, `to` and percentages, including comma lists and repeated
offsets. Repeated offsets merge in order. Unspecified fields and missing
endpoints use the widget's underlying style. Definitions follow the active
media conditions, layer priority and source order.

`sheet.motion_unsupported` counts rule entries and keyframes blocks containing
browser-only motion in parsed and packed sheets. This includes properties
such as `transform`, `steps()` timing, unequal transition timings, multiple
animations and `var()` in keyframes. Supported declarations in a mixed
keyframe still animate. The browser exporter preserves the original motion
declarations and `@keyframes` source. `css_tool pack-file NAME IN.css OUT.zi`
compiles a standalone native pack.

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
check, the production Kryon DOM test and the fuzzer. `make motion-test` uses
the current Kryon checkout to draw the same stylesheet from source and from
a generated pack through the retained Button renderer. The DOM test uses
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
