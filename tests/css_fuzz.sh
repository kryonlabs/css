#!/bin/sh
# Build tests/css_fuzz.zi with AddressSanitizer and UndefinedBehaviorSanitizer
# and run it: the corpus first, then generated sheets and damaged copies of
# the shipped packs and the KSS corpus.
#
#   sh tests/css_fuzz.sh SEED COUNT      COUNT cases from SEED
#   sh tests/css_fuzz.sh check FILE      the checks on one saved sheet
#
# A failing sheet is kept as build/css-fuzz/failure-SEED.css (or .kss).
set -eu

repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ziran=${ZIRAN:-ziran}
timeout=${FUZZ_TIMEOUT:-600}
if test "$#" -ne 2; then
    echo "usage: $0 SEED COUNT | check FILE" >&2
    exit 2
fi

cd "$repo"
include="$("$ziran" pkg path ziran 2> /dev/null)/include"
out=$repo/build/css-fuzz
rm -rf build/css-fuzz/c
mkdir -p "$out"
"$ziran" build --project --target=c --exe --entry css_fuzz:main \
    -o "$out/c" "$repo/tests/css_fuzz.zi" 2>&1 | { grep -v "local override" || true; }
"${CC:-cc}" -std=c11 -O1 -g -fno-omit-frame-pointer \
    -fsanitize=address,undefined -fno-sanitize-recover=all \
    -I"$include" -I"$out/c" "$out/c"/*.c -o "$out/css_fuzz" -lm

# The parser keeps large state; give the sanitized stack room.
ulimit -s unlimited 2>/dev/null || ulimit -s 1048576 2>/dev/null || true
current=$out/current
run() {
    env -u DISPLAY -u WAYLAND_DISPLAY ASAN_OPTIONS=detect_leaks=0 \
        timeout "$timeout" "$out/css_fuzz" "$current" "$@"
}
if test "$1" = check; then
    run check "$2"
    exit
fi
status=0
# Sheets that once failed come first.
run corpus tests/css_corpus/*.css tests/css_corpus/kss/*.kss || status=$?
if test "$status" -ne 0; then
    cp "$current" "$out/failure-corpus"
    echo "css fuzz: a corpus sheet failed; it is kept in build/css-fuzz/failure-corpus" >&2
    exit 1
fi
run "$1" "$2" styles/*.css tests/css_corpus/kss/*.ok.kss || status=$?
if test "$status" -ne 0; then
    cp "$current" "$out/failure-$1"
    if test "$status" -eq 124; then
        echo "css fuzz: seed $1 ran longer than $timeout seconds" >&2
    fi
    echo "css fuzz: failing sheet kept in build/css-fuzz/failure-$1" >&2
    echo "css fuzz: rerun it with sh tests/css_fuzz.sh check build/css-fuzz/failure-$1" >&2
    exit 1
fi
