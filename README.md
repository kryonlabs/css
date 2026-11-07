# Kryon CSS

Kryon applications are styled with a subset of CSS. This package parses
`.css` sheets into Kryon's style table, compiles style packs into tables apps
load without parsing, formats sheets, exports them to browser CSS for
Kryon's document host, and converts old KSS sheets. It ships the classic,
lightfield and material packs in `styles/`. The same table drives every
Kryon backend: desktop, console, Android, the web canvas and DOM hosts, and
apps built through the C, C++ and Go targets.

## Use it

```sh
ziran add https://github.com/kryonlabs/css.git
```

```zi
using Styles :: #import "css/Css";
#import "css/SystemStyle"

sheet: CssSheet;

Start :: () {
    if !CssSheetLoad(*sheet, StylePackClassic()) { return }
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
properties (`--accent`, for example) for one install. `SystemStyle`
installs the classic pack with colors that follow the desktop theme.

Imports go through a resolver you pass: `(name: string) -> CssImportAnswer`.
Hosts without imports pass `CssNoImports`.

## The subset

Selectors are a widget type (`Button`, `TextField`, `App`, `*`), classes
(`.primary`), Kryon attributes (`[role=Label]`, `[tone=Accent]`,
`[emphasis=Soft]`) and one state: `:hover`, `:active`, `:focus`,
`:focus-visible`, `:disabled`, `:selected`, `:checked` or `:loading`, in
comma lists. Combinators and nesting are outside the subset.

Properties: `color`, `background` (a color or a two-stop
`linear-gradient`), `background-color`, `border`, `border-color`,
`border-width`, `border-style` (`solid` or `none`), `border-radius`,
`outline-color`, `opacity`, `padding` (one or two values),
`padding-inline`, `padding-block`, `gap`, `font-size`, `font-family`,
`letter-spacing`, `translate`, `-kryon-material` (`lightfield`, `flat`,
`glass`) and `-kryon-icon-size`. Document layout properties (`width`,
`margin`, `display`, `transition` and the like) are kept for the web
document host and skipped by native hosts.

Values: hex, named, `rgb()`, `rgba()`, `hsl()` and `hsla()` colors; `px`
and `rem` (16px) lengths; `s` and `ms` durations; `var(--name, fallback)`.
`em` and `%` lengths are errors, because Kryon has no inherited font size
or containing block. Custom properties are declared in `:root`.

At-rules: `@import` (before other rules), `@layer` statements and blocks,
`@media` with `prefers-color-scheme`, `prefers-contrast`, `pointer`,
`min-width` and `max-width`, plus Kryon's `-kryon-theme`, `-kryon-density`,
`-kryon-pointer` and `-kryon-platform` features, and `@keyframes`.
`!important`, escapes and `//` comments are errors.

Rules rank by layer (unlayered rules last), then Kryon's specificity, then
source order. Kryon's specificity counts a widget type 1, each attribute 10,
a class 20 and a name 100; states add nothing, because a widget is in one
state at a time (disabled, loading, pressed, hovered, selected, focused, in
that order of precedence).

## Style packs

`styles/NAME.css` is compiled into `src/style_pack_NAME.zi`, a table of
words `CssSheetLoad(*sheet, StylePackNAME())` appends without parsing.
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
`data-kryon-widget`, `data-kryon-class` and ARIA attributes the host
writes; custom properties go on the root, `-kryon-*` declarations are
dropped, environment media queries are decided for `environment`, and
viewport queries stay for the browser. Every selector is wrapped in
`:where()` and rules are written in Kryon's priority order, so the browser
ranks them as native hosts do. Attribute selectors and unresolved imports
are refused with a message, never exported in part. `StyleClass(name)`
returns the class ID Kryon widget props take.

## From KSS

KSS, the earlier style language, is no longer read. `make migrate
IN=old.kss OUT=new.css` converts a sheet, and `CssMigrateKss(source,
output)` converts saved sheets in apps. Tokens become `:root` custom
properties, `@theme` becomes a media query, `foreground` becomes `color`,
`padding-x` and `padding-y` become `padding-inline` and `padding-block`,
`radius` becomes `border-radius`, `:pressed` becomes `:active`,
unitless numbers become `px`, and `[class=x]` becomes `.x`. A construct with
no CSS form, such as `@variant`, is an error naming its line.

## Develop

`make check` runs the behavior tests, the conformance test, the style pack
check and the fuzzer. The conformance test (`tests/css_conformance.sh`)
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
