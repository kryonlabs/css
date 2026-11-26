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
and media conditions, with what native Kryon does instead. A rejected selector or
at-rule skips its entire block. The check exits with status 1 when it skipped
anything natively; browser-only declarations alone leave it at 0.
`build/tools/css_tool check --strict app.css` exits with status 1 if any issue is
reported. Both modes exit with status 1 when the stylesheet cannot be recovered.
The CLI checks the given source and treats imports as empty sheets.

Apps can use `CssSheetParseWithDiagnostics(sheet, source, path, resolve, options)`
from `css/Css` to recover while parsing. Set `options.report` to a `CssIssueSink`
with signature `(context: *void, issue: CssIssue) -> void`. Each issue supplies
its origin, item kind, name, reason and `web_only` flag. Copy any text you need
after the callback returns. Imported issues use the paths from the host's
resolver. Set `options.strict = true` to collect the same issues and reject the
sheet. The plain `CssSheetParse` reads native sheets and fails fast: a
browser-only declaration is an error there, never skipped silently. Read a
sheet shared with the browser export through `CssSheetParseWithDiagnostics`,
which keeps the native rules and reports each browser-only declaration with
`web_only` set. Packs are native, so `css_tool pack` refuses one too. `CssSheetBuild` and installation still validate values after
resolving custom properties in the chosen environment.

## The subset

Each selector can combine a widget type (`Button`, `TextField`, `Row`,
`Column`, `Grid`, `App`, `*`),
one class (`.primary`), one ID (`#save`; set `props.id` to `StyleId("save")`),
Kryon attributes (`[role=Label]`, `[tone=Accent]`, `[emphasis=Soft]`,
`[size=Small]`, `[state=normal]`) and one state pseudo-class:
`:hover`, `:active`, `:focus`, `:focus-visible`, `:disabled`, `:selected`,
`:checked` or `:loading`, in comma lists. `:not(.class)` and `:not(:state)`
add tree context, and so may one ancestor, matched by its class or id, before
the compound: `.card Text` (any ancestor) or `.card > Text` (the parent).
Structural positions also work: `:first-child`, `:last-child`, `:only-child`,
`:nth-child(an+b)`, `:first-of-type`, `:last-of-type`, `:only-of-type` and
`:nth-of-type(an+b)` (`.item:nth-child(2)`, `Text:last-child`). Early facts
match while the frame builds; late facts (`:last-child` family) read the
previous frame's children, so a structure change converges on the next frame.
A typed ancestor (`Row Text`), a second ancestor (`.a .b .c`) and sibling
combinators (`+`, `~`) are errors: give the inner widget its own class
(`Text.card-title`). A rule can hold nested `&:state`,
`&.class`, `&#id`, `&[attribute]`, `&:first-child` and `&:not(...)` rules one
level deep; each adds its parts to every parent selector and may not set a
class, id, attribute or state the parent sets to another value.

Properties a native sheet reads, generated from the parser's own catalog
(`src/parser/catalog.zi`); every example parses on its target in the tests.
Anything else is browser-only or an error.

<!-- properties:start -->
| Property | Applies to | Example | Values |
| --- | --- | --- | --- |
| `color` | `*` | `#203040` | color, var(), color-mix() |
| `background` | `Column` | `radial-gradient(circle closest-side at 25% 25%, #0ea5e9, #a855f7)` | color, linear-gradient() (angle or to side/corner) or radial-gradient() (shape, extent or radii, at position); 2-6 stops with % positions |
| `background-color` | `*` | `rgb(10 20 30)` | color |
| `border` | `*` | `1px solid #ccddee` | width (or thin, medium, thick), solid or none, color |
| `border-color` | `*` | `hsl(200 50% 40%)` | color |
| `border-width` | `*` | `1px` | length |
| `border-style` | `*` | `solid` | solid or none |
| `border-radius` | `*` | `calc(4px + 0.25rem)` | one length |
| `outline-color` | `*` | `#38bdf8` | color (focus ring) |
| `opacity` | `*` | `80%` | number or percentage |
| `box-shadow` | `Card` | `0 1px 3px #0003` | none, or shadows: elevation raised (blur <= 8px) or floating |
| `padding` | `*` | `4px 8px` | 1-4 lengths; opposite sides equal |
| `padding-inline` | `*` | `clamp(8px, 2vw, 20px)` | length |
| `padding-block` | `*` | `0.5em` | length |
| `gap` | `*` | `8px 12px` | normal or 1-2 lengths (row, column) |
| `row-gap` | `*` | `4px` | normal or length |
| `column-gap` | `*` | `max(8px, 1vw)` | normal or length |
| `width` | `Column` | `50%` | auto, a positive static length or a percentage |
| `height` | `Row` | `48px` | auto, a positive static length or a percentage |
| `min-width` | `Column` | `120px` | static length or percentage |
| `max-width` | `Column` | `calc(50rem - 100px)` | static length, percentage or none |
| `max-height` | `Column` | `80%` | static length, percentage or none |
| `min-inline-size` | `Grid` | `100px` | static length or percentage |
| `max-inline-size` | `Grid` | `none` | static length, percentage or none |
| `max-block-size` | `Row` | `200px` | static length, percentage or none |
| `min-height` | `Button` | `44px` | length; a percentage on Row, Column and Grid |
| `min-block-size` | `Button` | `2.75rem` | length |
| `margin` | `Column` | `0 auto` | 1-4 static lengths or auto |
| `margin-top` | `Column` | `8px` | static length or auto |
| `margin-right` | `Column` | `auto` | static length or auto |
| `margin-bottom` | `Column` | `1rem` | static length or auto |
| `margin-left` | `Row` | `auto` | static length or auto |
| `margin-inline` | `Grid` | `16px` | 1-2 static lengths or auto |
| `margin-block` | `Grid` | `8px 4px` | 1-2 static lengths or auto |
| `margin-inline-start` | `Row` | `4px` | static length or auto |
| `margin-inline-end` | `Row` | `auto` | static length or auto |
| `overflow` | `Column` | `hidden` | visible, hidden or clip |
| `text-align` | `Text` | `center` | start, left, center, end or right |
| `display` | `Row` | `flex` | flex (Row, Column) or grid (Grid) |
| `flex-direction` | `Row` | `row-reverse` | row, column and their -reverse |
| `flex-wrap` | `Row` | `wrap-reverse` | wrap, wrap-reverse or nowrap |
| `justify-content` | `Row` | `space-between` | normal, flex-start, center, flex-end, space-between, -around, -evenly |
| `align-items` | `Row` | `center` | start, center, end, stretch, normal |
| `align-self` | `Text` | `flex-end` | auto, start, center, end, stretch |
| `flex` | `Column` | `1` | none, auto, initial, or grow [shrink] [basis] |
| `flex-basis` | `Text` | `25%` | auto, a static length or a percentage |
| `flex-grow` | `Text` | `2` | number |
| `flex-shrink` | `Text` | `0` | number |
| `grid-template-columns` | `Grid` | `repeat(3, minmax(0, 1fr))` | 1fr, repeat(N, 1fr), repeat(auto-fit, minmax(LENGTH, 1fr)) |
| `font` | `Text` | `italic 600 15px/1.5 system-ui, sans-serif` | [style] [weight] size[/line-height] families |
| `font-family` | `Text` | `"Inter", sans-serif` | first family; generic families keep the theme face, monospace is code |
| `font-size` | `Text` | `clamp(14px, 1vw + 10px, 18px)` | length |
| `font-weight` | `Text` | `bold` | normal, bold or 1-1000 |
| `font-style` | `Text` | `italic` | normal, italic or oblique |
| `letter-spacing` | `Text` | `-0.02em` | normal or a signed length |
| `line-height` | `Text` | `1.5` | normal, number, percentage or length |
| `-kryon-content-offset` | `*` | `2px 4px` | x [y] lengths: a widget part's offset or metric |
| `transition` | `Button` | `background-color 180ms ease-out` | native properties, durations, easing, delay |
| `transition-property` | `Button` | `color` | native properties or all |
| `transition-duration` | `Button` | `120ms` | duration |
| `transition-timing-function` | `Button` | `ease-in-out` | keyword or cubic-bezier() |
| `transition-delay` | `Button` | `40ms` | duration |
| `transition-behavior` | `Button` | `normal` | normal |
| `animation` | `Button` | `pulse 1s infinite` | name, duration, easing, delay, count, direction, fill |
| `animation-name` | `Button` | `pulse` | @keyframes name |
| `animation-duration` | `Button` | `1s` | duration |
| `animation-timing-function` | `Button` | `linear` | keyword or cubic-bezier() |
| `animation-delay` | `Button` | `0s` | duration |
| `animation-iteration-count` | `Button` | `infinite` | number or infinite |
| `animation-direction` | `Button` | `alternate` | normal, reverse, alternate, alternate-reverse |
| `animation-fill-mode` | `Button` | `both` | none, forwards, backwards, both |
| `animation-play-state` | `Button` | `running` | running or paused |
| `-kryon-material` | `*` | `glass` | lightfield, flat or glass |
| `-kryon-icon-size` | `*` | `20px` | length |
| `-kryon-font-role` | `*` | `code` | inherit, control, body, heading, code |
| `-kryon-elevation` | `*` | `floating` | none, rest, raised, floating |
| `-kryon-motion-duration` | `*` | `150ms` | duration |
| `-kryon-motion-multiplier` | `*` | `1.5` | number |
| `-kryon-motion-easing` | `*` | `standard` | inherit, standard, linear, instant |
| `-kryon-motion-reduced` | `*` | `reduce` | reduce or no-preference |
| `border-top` | `Column` | `1px solid #d0d7de` | one side, as border; also -right, -bottom, -left and the block/inline-start/end sides |
| `border-bottom-width` | `Row` | `thick` | length, thin, medium or thick; every side has -width |
| `border-left-color` | `Column` | `var(--kryon-accent)` | color; every side has -color |
| `border-inline-start-style` | `Grid` | `none` | solid or none; every side has -style |
| `outline` | `Button` | `2px solid #38bdf8` | [width] [solid, auto or none] [color]: the focus ring |
| `outline-width` | `Button` | `3px` | length, thin, medium or thick |
| `outline-offset` | `Button` | `2px` | signed length outside the edge |
| `background-image` | `Row` | `linear-gradient(to right, #111827, #374151)` | none, linear-gradient() or radial-gradient() |
| `transform` | `Column` | `translateY(-2px) scale(1.02)` | none, or translate(), scale() and rotate() with their X and Y forms |
| `translate` | `Column` | `0 -2px` | none, or x [y] lengths; moves the whole box |
| `scale` | `Button` | `1.05` | none, or one or two numbers or percentages |
| `rotate` | `Text` | `-3deg` | none or an angle |
| `transform-origin` | `Column` | `left top` | left, center, right, top, bottom, lengths or percentages |
<!-- properties:end -->

- `box-shadow` selects a Kryon elevation role: `none` clears it, a shadow
  whose largest blur is at most 8px is `raised` and a softer one `floating`
  (the widgets that draw elevation, such as Card and Modal, use their own
  shadow geometry and colors, and Row, Column and Grid paint it under their
  box). `font: [style] [weight] size[/line-height] family` sets those fields.
  A generic first family (`system-ui`, `sans-serif`, `serif`) keeps the
  theme's typeface and `monospace` or `ui-monospace` selects the `code` font
  role; a named first family is the typeface and later families are ignored
  natively. `linear-gradient()` takes an angle or `to` a side or corner and
  two to six stops with `%` positions; Row, Column and Grid paint all of
  them, other widgets a top-to-bottom gradient of the first and last colors.
  Radial, conic and repeating gradients are browser-only.

- `transform` takes `translate()`, `scale()` and `rotate()` and their X and Y
  forms in any order that does not shear, and `scale`, `rotate` and
  `transform-origin` are read too. Kryon applies them when it paints, on
  every host, about the origin (the center of the box unless set), to the
  widget and everything inside it; layout and pointer hit areas keep the
  untransformed box. Row, Column, Grid, Button, Card, Text, Heading, Link
  and Image take transforms, with `:hover` and `:active` following the
  pointer, and `transition: transform 150ms` (or `all`) eases a change. A
  transform rule matches its node by type, class, id and state; an ancestor
  or `:first-child` in its selector does not apply. A whole-pixel
  translation paints exactly as without it; a scale or rotation draws boxes
  as triangles, text at the nearest whole font size and images scaled and
  turned. `translate()` percentages, skew, `matrix()` and 3D functions are
  browser-only. Transforms are opt-in paint code: the app imports
  `kryon/paint_transform` and calls `PaintTransformInstall()` once before
  its first frame, and `CssSheetInstall` refuses a sheet that sets a
  transform until it has.

- `gap` takes one value for both axes or two values in row, column order.
  `row-gap` and `column-gap` cascade independently. Gaps take `normal`
  (zero in native layout) or a nonnegative `px` or `rem` length. A `Row`
  uses its column gap and a `Column` uses its row gap. A `Grid` uses both independently.
  Controls that use a uniform gap read the first `gap` value.
- `Row`, `Column` and `Grid` read `width` and `height` as outer sizes, including
  padding. They accept positive lengths (including a static `calc()`) and `auto`. A positive
  axis in `props.bounds` takes precedence. Otherwise `auto` uses the ordinary
  parent content size or the measured height of a grid or flex container with
  declared items. `auto` can override an earlier size rule. Other sizing
  values, including zero, percentages, intrinsic keywords, `var()` and
  `vw`/`vh` sizes, are browser-only and are skipped by native layout. Browser export
  keeps both sets of values. Native packs accept the native subset.
- `Row`, `Column` and `Grid` read `min-width`, `max-width` and `max-height`
  (`px`, `rem`, `0`, and `none` for maxima, with the logical `-inline-size` and
  `-block-size` aliases), margins (`margin` with one to four values, each side,
  `margin-inline`, `margin-block`; `px`, `rem`, `0` or `auto`) and `overflow`
  (`visible`, `hidden` or `clip`). Margins move the container inside the slot
  its parent places; `auto` inline margins share the free width, so
  `max-width: 1200px; margin: 0 auto` centers a column. `overflow: hidden`
  clips descendants. `Text`, `Heading`, `ParagraphText` and `Link` read
  `text-align` (`start`, `left`, `center`, `end`, `right`). Negative margins,
  percentages and `overflow: auto` or `scroll` are browser-only; native
  scrolling is `Scroll.Draw`.
- `Grid` supports `1fr`, `minmax(0, 1fr)`, `repeat(N, 1fr)`,
  `repeat(N, minmax(0, 1fr))` and `repeat(auto-fit, minmax(LENGTH, 1fr))`.
  `N` is 1–1024 and `LENGTH` is a positive `px` or `rem` length. The
  responsive spelling `min(LENGTH, 100%)` also works as the minimum.
  Other track expressions remain available to browser export. Choose
  `Layout.Grid` in the app frame and provide item heights or width-aware
  measurements and any spans.
- `display: flex` maps to measured `Layout.Row` and `Layout.Draw` containers.
  Pass `[]Layout.FlexItem` and `[]Layout.FlexPlacement` to either API, then
  draw each child in its placement's `bounds`. Set the item's style `kind`,
  `id` and `class_name` when a selector matches it. `display: grid` maps
  to `Layout.Grid`. Native code selects the container.
- Flex directions are `row`, `row-reverse`, `column` and `column-reverse`.
  Lines support `wrap`, `wrap-reverse` and `nowrap` and use the main-axis and
  cross-axis gaps. Justification supports `normal`, `flex-start`, `center`,
  `flex-end`, `space-between`, `space-around` and `space-evenly`. Alignment
  supports `start`/`flex-start`, `center`, `end`/`flex-end`, `stretch`,
  `normal`, `baseline` and `auto` for `align-self`, with `align-content`
  distributing wrapped lines the same way. Stretch fills an unset cross
  extent. Flex basis accepts `auto`, nonnegative `px` and `rem`, zero, and a
  percentage of the container's inner main size. The `flex` shorthand also
  accepts `none`, `auto` and `initial`. Intrinsic basis keywords
  (`min-content`, `max-content`, `fit-content`) remain outside this native
  subset.
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
`px`, `rem` (16px), `em`, `vw` and `vh` lengths and `calc()`, `min()`, `max()`
and `clamp()` over them; `s` and `ms` durations; `var(--name, fallback)`,
whose fallback may be one more `var(--other, literal)`; and `var(--kryon-NAME)`
for the installed theme's `background`, `surface`, `raised`, `sunken`, `text`,
`muted`, `disabled`, `border`, `border-strong`, `accent`, `accent-strong`,
`selection`, `selection-text`, `success`, `warning` and `danger` colors when
the sheet does not define that name.
Hue accepts a number in degrees or `deg`, `grad`, `rad` or `turn`. Write
`hwb(hue white% black% / alpha)` with spaces between channels and optional
alpha as a number or percentage. Colors are stored as 8-bit RGBA.
An expression without `vw` or `vh` folds to pixels when the sheet is read.
`em` is the rule's own `font-size` when it sets one, else 16px (there is no
inherited font size). `vw` and `vh` resolve when the sheet installs, against
`CssEnvironmentWithViewportWidth` and `CssEnvironmentWithViewportHeight`
(1024x768 when unset); `CssSheetSameMedia` reports a change when a new
viewport changes any active rule's length, so reinstall then. Lengths with
`vw` or `vh` work in padding, gap, radius, border width, font size, letter
spacing and min-height; `width`, `height`, box and flex lengths take static
expressions only. A `min()` or `max()` with viewport units takes two
arguments and cannot nest. `%` lengths are errors: there is no containing
block. Custom properties are declared in `:root`, keep the type
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
  from { opacity: 0; -kryon-content-offset: 0 4px; }
  to { opacity: 1; -kryon-content-offset: 0 0; }
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
such as `filter`, `steps()` timing, unequal transition timings, multiple
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
horizontal padding. Use the measured Kryon layout APIs with the CSS flex and
grid declarations above. Text emphasis, alignment and wrapping are widget props
where available.

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
