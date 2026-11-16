#!/bin/sh
# GNU Make built for the PC from the same sources, patches/ and gnulib
# files as the GFOS build, with config.h from the same probe
# (scripts/mk-common.sh, PC platform: jobserver, POSIX children), then
# upstream's own test suite (tests/run_make_tests.pl, needs perl).
#   sh tests/host-make.sh
# Run as root, three upstream cases can't fail the way they expect (an
# unwritable TMPDIR, an unreadable makefile, a killed child): those are
# listed in tests/root-skips.txt and only skipped for root.
# MIT, Copyright (c) 2026 AmiCradle Team.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
. "$HERE/make.lock"
. "$HERE/scripts/mk-common.sh"
WORK=${WORK:-"$HERE/build-host"}; CC=${HOST_CC:-cc}
mkdir -p "$WORK"; WORK=$(cd "$WORK" && pwd)
SRC="$WORK/make"; GL="$WORK/gnulib"
mk_source "$SRC" "$GL"
PROBE_CC="$CC" mk_config "$SRC" pc "$WORK/gen" "$GL"
O="$WORK/obj"; rm -rf "$O"; mkdir -p "$O"
CF="-O2 -w -DHAVE_CONFIG_H -I$WORK/gen -I$SRC/src -DLIBDIR=\"/usr/local/lib\" -DINCLUDEDIR=\"/usr/local/include\" -DLOCALEDIR=\"/usr/local/share\""
objs=""
for f in $MAKE_SRCS posixos.c; do
    # shellcheck disable=SC2086
    $CC $CF -c "$SRC/src/$f" -o "$O/${f%.c}.o" & objs="$objs $O/${f%.c}.o"
done
for f in $GL_SRCS; do
    b=$(basename "$f" .c)
    # shellcheck disable=SC2086
    $CC $CF -c "$SRC/$f" -o "$O/gl_$b.o" & objs="$objs $O/gl_$b.o"
done
for f in $GNULIB_SRCS; do
    # shellcheck disable=SC2086
    $CC $CF -c "$GL/lib/$f" -o "$O/gnulib_${f%.c}.o" & objs="$objs $O/gnulib_${f%.c}.o"
done
wait
# shellcheck disable=SC2086
$CC -o "$WORK/make-host" $objs
echo "built: $("$WORK/make-host" --version | head -1)"

T="$WORK/tests"; rm -rf "$T"; cp -R "$SRC/tests" "$T"
sed -e 's/@CC@/cc/' -e 's/@USE_SYSTEM_GLOB@/no/' -e 's/@[A-Z_]*@//g' "$T/config-flags.pm.in" > "$T/config-flags.pm"
(cd "$T" && perl ./run_make_tests.pl -srcdir "$SRC" -make "$WORK/make-host" > "$WORK/make-tests.log" 2>&1) || true
fail=0
# a test file's name starts its line; FAILED can come lines later
failed=$(awk '/^[a-z_-]+\/[A-Za-z0-9_.-]+ \.\.\./ {cur=$1} /FAILED/ && cur != "" {print cur}' "$WORK/make-tests.log" | sort -u)
# the test files with failures, less those root-skips.txt allows when root
bad=""
for f in $failed; do
    if [ "$(id -u)" = 0 ] && grep -qx "$f" "$HERE/tests/root-skips.txt"; then continue; fi
    bad="$bad $f"
done
total=$(grep -oE '\(([0-9]+) passed\)' "$WORK/make-tests.log" | grep -oE '[0-9]+' | awk '{s+=$1} END {print s}')
if [ -n "$bad" ]; then
    echo "FAIL make tests:$bad"; grep -B1 FAILED "$WORK/make-tests.log" | head -20; fail=1
else
    echo "make tests: $total cases passed$( [ -n "$failed" ] && echo "; root-only skips: $(echo $failed)")"
fi
# the lab's language test (tests/amiga/funcs.mk) on the same build
if out=$("$WORK/make-host" -f "$HERE/tests/amiga/funcs.mk" 2>&1) && echo "$out" | grep -q "checks passed"; then
    echo "$out" | grep "checks passed"
else
    echo "FAIL funcs.mk: $out"; fail=1
fi
exit $fail
