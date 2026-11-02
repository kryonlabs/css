# KSS

KSS is the style sheet language of [Kryon](https://github.com/kryonlabs/kryon)
applications. This package parses and formats `.kss` sheets, resolves their
`@import`s and color tokens, installs the rules into Kryon's style table, and
ships the classic, lightfield, and material style packs in `styles/`. Kryon
itself only resolves installed rules; apps that read `.kss` text add this
package.

## Use it

```sh
ziran add https://github.com/kryonlabs/kss.git
```

```zi
using Styles :: #import "kss/Kss";
#import "kss/SystemStyle"
```

`BeginStyleRules`, `ParseStyleRules`, and `InstallParsedStyleRules` parse a
sheet in steps and install it; `ProvideStyleRulesImport` answers an
`@import`. `SystemStyle` picks a pack that matches the desktop theme. The
classic pack is also compiled in as `style_pack_classic`, so an app can
install it without shipping the `.kss` file.

Customization hosts can use `KssAddTokenOverride` before parsing to override
color, length, duration, or material tokens throughout a pack. A later override
of the same name and kind replaces the earlier value. Names are owned by the
parser; invalid names and exhausted capacity produce diagnostics. Rule
installation validates the new snapshot before replacing existing colors.

## Develop

`ExportCSS(source, path, environment, output)` exports a supplied KSS source
unit to CSS for Kryon's document host. Use the bytes through `result.count`
only when `result.ok` is true. `StyleClass(name)` returns the class ID accepted
by Kryon widget props. The exporter shares the parser, token resolution and
environment rules; widget/class/state selectors become scoped DOM selectors,
numeric units and axis properties are expanded, and media conditions survive.
Source and saved IR run on C, C++ and Go in `tests/css_export_test.sh`.
The C++ host compiles Ziran's generated C output as C++17.

The current export subset rejects unresolved imports, KSS layers, nested
selector functions, native materials, unknown foreign blocks and output
overflow. Resolve imports or flatten layers before export. Unsupported output
is reported explicitly rather than producing a usable partial sheet. Browser
CSS keywords and authored units remain literal values. Native-only effects
such as gradient endpoints and materials need an explicit browser stylesheet.

`make check` checks the package, runs the parser and style tests as portable
bundles and native code, verifies that `src/style_pack_classic.zi` matches
`styles/classic.kss`, and fuzzes generated and damaged sheets under
AddressSanitizer and UndefinedBehaviorSanitizer. After editing
`styles/classic.kss`, run `make style-packs` and commit the regenerated
module with it. `make fuzz FUZZ_SEED=N FUZZ_COUNT=M` runs other sheets; a
failing one is kept in `build/kss-fuzz/` with a command that shrinks it.

To test against the local compiler and Kryon checkouts, put this in an
ignored `ziran.local.toml`:

```toml
[overrides]
ziran = "../../../ziranlang/ziran"
kryon = "../../kryon"
```
