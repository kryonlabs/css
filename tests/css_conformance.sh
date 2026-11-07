#!/bin/sh
# The same style sheets must resolve the same on every Kryon backend. Each
# host prints the digests of tests/css_conformance.zi and must print
# tests/css_conformance.expected exactly:
#   C        the generated C program (desktop, console and other C hosts)
#   C++      a C++ host linking the generated C as a library
#   Go       the Go target, under `go test`
#   ZX       a ziran bundle run by the ZX runtime
#   Android  the C program built with the NDK and run on a phone over adb
#            (CSS_ANDROID_SERIAL picks the phone; skipped without one)
#   web      the DOM export in headless Chromium, compared value by value
#            with what Kryon resolves (skipped without Chromium)
# Run from the repository root: make conformance.
set -eu

ZIRAN=${ZIRAN:-ziran}
CC=${CC:-cc}
CXX=${CXX:-c++}
OUT=build/conformance
EXPECTED=tests/css_conformance.expected
INCLUDE="$("$ZIRAN" pkg path ziran 2> /dev/null)/include"

quiet() {
    # Drop the local-override notes ziran prints during development.
    grep -v "local override" || true
}

same() {
    if ! diff -u "$EXPECTED" "$2"; then
        echo "css conformance: $1 differs from $EXPECTED" >&2
        exit 1
    fi
    echo "css conformance: $1 matches"
}

rm -rf build/conformance
mkdir -p "$OUT"

# C
"$ZIRAN" build --project --target=c --exe --entry css_conformance_main:main \
    -o "$OUT/c" tests/css_conformance_main.zi 2>&1 | quiet
"$CC" -std=c11 -O1 -I"$INCLUDE" -I"$OUT/c" "$OUT"/c/*.c -o "$OUT/css_conformance" -lm
"$OUT/css_conformance" > "$OUT/c.txt"
same C "$OUT/c.txt"

# C++: the generated C as a library.
"$ZIRAN" build --project --target=c -o "$OUT/lib" tests/css_conformance.zi 2>&1 | quiet
mkdir -p "$OUT/obj"
for source in "$OUT"/lib/*.c; do
    "$CC" -std=c11 -O1 -I"$INCLUDE" -I"$OUT/lib" -c "$source" -o "$OUT/obj/$(basename "$source" .c).o"
done
"$CXX" -std=c++17 -O1 tests/css_conformance_host.cpp "$OUT"/obj/*.o -o "$OUT/css_conformance_cpp" -lm
"$OUT/css_conformance_cpp" > "$OUT/cpp.txt"
same C++ "$OUT/cpp.txt"

# Go
"$ZIRAN" build --project --target=go -o "$OUT/go" tests/css_conformance.zi 2>&1 | quiet
cp tests/css_conformance_go_test.go "$OUT/go/"
(cd "$OUT/go" && GO111MODULE=off go test -count=1 -run TestCssConformance -v .) > "$OUT/go.log"
sed -n 's/^conformance //p' "$OUT/go.log" > "$OUT/go.txt"
same Go "$OUT/go.txt"

# ZX: the bundle returns the combined digest.
"$ZIRAN" bundle --project --entry css_conformance:CssConformanceAll -o "$OUT/conformance.zx" \
    tests/css_conformance.zi 2>&1 | quiet
# The bundle is run by the toolchain that wrote it, the project's own; where
# that is not built, the portable runtime runs the entry from source.
TOOLCHAIN="$("$ZIRAN" pkg path ziran 2> /dev/null)/build/bin/ziran"
if [ -x "$TOOLCHAIN" ]; then
    echo "all $("$TOOLCHAIN" run "$OUT/conformance.zx")" > "$OUT/zx.txt"
else
    echo "all $("$ZIRAN" run --entry css_conformance:CssConformanceAll tests/css_conformance.zi 2>&1 | quiet)" > "$OUT/zx.txt"
fi
if ! grep -qx "$(cat "$OUT/zx.txt")" "$EXPECTED"; then
    echo "css conformance: ZX printed '$(cat "$OUT/zx.txt")', expected the 'all' line of $EXPECTED" >&2
    exit 1
fi
echo "css conformance: ZX matches"

# Android
NDK=${ANDROID_NDK_HOME:-}
if [ -z "$NDK" ] && [ -d "$HOME/Android/Sdk/ndk" ]; then
    NDK="$HOME/Android/Sdk/ndk/$(ls "$HOME/Android/Sdk/ndk" | sort -V | tail -n 1)"
fi
SERIAL=${CSS_ANDROID_SERIAL:-}
if [ -z "$SERIAL" ] && command -v adb > /dev/null 2>&1; then
    SERIAL=$(adb devices | awk 'NR > 1 && $2 == "device" { print $1; exit }')
fi
if [ -n "$NDK" ] && [ -n "$SERIAL" ]; then
    ABI=$(adb -s "$SERIAL" shell getprop ro.product.cpu.abi | tr -d '\r')
    case "$ABI" in
        arm64-v8a) TRIPLE=aarch64-linux-android21 ;;
        armeabi-v7a) TRIPLE=armv7a-linux-androideabi21 ;;
        x86_64) TRIPLE=x86_64-linux-android21 ;;
        *) TRIPLE= ;;
    esac
    if [ -z "$TRIPLE" ]; then
        echo "css conformance: Android skipped, no compiler for ABI '$ABI'"
    else
        "$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin/$TRIPLE-clang" -std=c11 -O1 \
            -I"$INCLUDE" -I"$OUT/c" "$OUT"/c/*.c -o "$OUT/css_conformance_android" -lm
        adb -s "$SERIAL" push "$OUT/css_conformance_android" /data/local/tmp/kryon_css_conformance > /dev/null
        adb -s "$SERIAL" shell chmod 755 /data/local/tmp/kryon_css_conformance
        adb -s "$SERIAL" shell /data/local/tmp/kryon_css_conformance | tr -d '\r' > "$OUT/android.txt"
        adb -s "$SERIAL" shell rm -f /data/local/tmp/kryon_css_conformance
        same "Android ($ABI)" "$OUT/android.txt"
    fi
else
    echo "css conformance: Android skipped (needs the NDK and a phone on adb)"
fi

# Web
CHROMIUM=${CHROMIUM:-$(command -v chromium || command -v chromium-browser || command -v google-chrome || true)}
if [ -n "$CHROMIUM" ]; then
    mkdir -p "$OUT/web"
    "$OUT/css_conformance" web "$OUT/web"
    # Chromium's socket path must be short, so its files live under /tmp.
    BROWSER_TMP=$(mktemp -d /tmp/kryon-css.XXXXXX)
    for theme in light dark; do
        TMPDIR="$BROWSER_TMP" timeout 120 "$CHROMIUM" --headless=new --no-sandbox \
            --use-gl=disabled --disable-gpu --no-first-run \
            --user-data-dir="$BROWSER_TMP/profile" \
            --dump-dom "file://$PWD/$OUT/web/$theme.html" 2> "$OUT/web/$theme.log" > "$OUT/web/$theme.dom" || true
        if ! grep -q '<pre id="conformance-result">CONFORMANCE PASS [0-9]' "$OUT/web/$theme.dom"; then
            sed -n '/conformance-result/,/<\/pre>/p' "$OUT/web/$theme.dom" | sed 's/ data-expect="[^"]*"//g' >&2
            tail -n 5 "$OUT/web/$theme.log" >&2
            case "$BROWSER_TMP" in /tmp/kryon-css.*) rm -r -- "$BROWSER_TMP" ;; esac
            echo "css conformance: browser export differs from Kryon in the $theme scheme" >&2
            exit 1
        fi
        echo "css conformance: web $theme, $(sed -n 's/.*<pre id="conformance-result">CONFORMANCE PASS \([0-9]*\).*/\1/p' "$OUT/web/$theme.dom") values match"
    done
    case "$BROWSER_TMP" in /tmp/kryon-css.*) rm -r -- "$BROWSER_TMP" ;; esac
else
    echo "css conformance: web skipped (no Chromium)"
fi
