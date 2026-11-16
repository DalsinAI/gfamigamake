#!/bin/sh
# Builds GNU Make for GFOS (AmigaOS 3.2.3 with GFOpenUp) with a stove: 68040,
# soft float with the FPU taken when there is one (fpuauto), upstream's own
# Amiga code (src/amiga.c: commands through SystemTags() and the user's
# Shell, AmigaDOS wildcards in $(wildcard)).
#   STOVE=.../stoves/os32-gcc16-open6 OUT=out ./build-amiga.sh
# Make, gnulib and fpuauto are fetched at the commits make.lock gives;
# nothing third-party is kept here. The PC tests (tests/host-make.sh:
# upstream's own test suite on the same sources) run first when there is a
# PC compiler and perl; HOST_TESTS=0 skips them.
# OUT gets Parts/Make: a GFOpenUp part (its Part file, C:make, the ReadMe
# and GNU Make's licence in SYS:Docs/Make), installed with
#   GFOpenUpTool INSTALL Parts/Make
# and tests/: a few makefiles for a lab run.
# MIT, Copyright (c) 2026 AmiCradle Team.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$HERE/make.lock"
. "$HERE/scripts/mk-common.sh"
STOVE=${STOVE:-"$HOME/AmiCradle/stoves/os32-gcc16-open6"}
# outside the checkout: Cradle cleans it (git clean -ffdx) before every job
WORK="${WORK:-$HOME/.cache/gfamigamake/build}"; OUT="${OUT:-$WORK/out}"; JOBS=${JOBS:-8}
# the PC tests run on the PC's own PATH, not the stove's
HOST_PATH=$PATH
TC="$STOVE/prefix"; PATH="$TC/bin:$PATH"; export PATH
mkdir -p "$WORK/deps" "$OUT"; OUT=$(cd "$OUT" && pwd)
t0=$(date +%s)

# --- the PC tests first: the same sources, upstream's test suite ----------------
if [ "${HOST_TESTS:-1}" != 0 ] && (PATH=$HOST_PATH; command -v "${HOST_CC:-cc}" && command -v perl) > /dev/null 2>&1; then
    PATH=$HOST_PATH WORK="$WORK/host" sh "$HERE/tests/host-make.sh" > "$WORK/host-tests.log" 2>&1 || { tail -30 "$WORK/host-tests.log"; exit 1; }
    grep -E "^make tests:|checks passed" "$WORK/host-tests.log"
fi

# --- fpuauto: libfpuauto.a and its link specs ---------------------------------
FPD="$WORK/deps/fpuauto"
if [ "$(git -C "$FPD" rev-parse HEAD 2>/dev/null)" != "$FPA_COMMIT" ]; then
    rm -rf "$FPD"; mkdir -p "$FPD"; git -C "$FPD" init -q
    git -C "$FPD" config core.sparseCheckout true
    echo "/common/fpuauto/" > "$FPD/.git/info/sparse-checkout"
    git -C "$FPD" fetch -q --depth 1 --filter=blob:none "$FPA_REPO" "$FPA_COMMIT"
    git -C "$FPD" checkout -q FETCH_HEAD
fi
FA="$FPD/common/fpuauto"; FAL="$WORK/fpuauto"
if [ ! -f "$FAL/libfpuauto.a" ] || [ "$(cat "$FAL/.rev" 2>/dev/null)" != "$FPA_COMMIT" ]; then
    rm -rf "$FAL"; mkdir -p "$FAL/obj"
    m68k-amigaos-gcc -m68040 -DFPUAUTO_COMMON -c "$FA/fpuauto.S" -o "$FAL/obj/fa_common.o"
    for n in $(sed 's/^--wrap=//' "$FA/fpuauto.wraps"); do
        m68k-amigaos-gcc -m68040 -DR_$n -c "$FA/fpuauto.S" -o "$FAL/obj/fa_$n.o"
    done
    m68k-amigaos-ar rcs "$FAL/libfpuauto.a" "$FAL"/obj/fa_*.o
    echo "$FPA_COMMIT" > "$FAL/.rev"
fi

# --- Make and gnulib at their pinned commits, patches/, config.h --------------------
SRC="$WORK/make"; GL="$WORK/deps/gnulib"
mk_source "$SRC" "$GL"
LINK="m68k-amigaos-gcc -noixemul -m68040 -specs=$HERE/scripts/m68k-soft-m68040.specs -specs=$FA/fpuauto.specs -L$FAL"
PROBE_CC="$LINK" mk_config "$SRC" gfos "$WORK/gen" "$GL"
echo "probe: $(grep -c '^#define HAVE_' "$WORK/gen/config.h") functions and headers found"

# --- compile -------------------------------------------------------------------
LATE=""
if m68k-amigaos-gcc -fno-late-combine-instructions -S -o /dev/null -x c /dev/null 2>/dev/null; then LATE="-fno-late-combine-instructions"; fi
# no loops turned into memset/memcpy calls (GCC 16), address 0 is memory
CF="-noixemul -m68040 -O2 -fno-tree-loop-distribute-patterns -fno-delete-null-pointer-checks $LATE \
 -std=gnu99 -Werror=implicit-function-declaration -Werror=int-conversion -DHAVE_CONFIG_H \
 -I$WORK/gen -I$SRC/src -DLIBDIR=\\\"LIBS:\\\" -DINCLUDEDIR=\\\"INCLUDE:\\\" -DLOCALEDIR=\\\"LOCALE:\\\" \
 -DMAKE_AMIGA_VERSION=\\\"$MAKE_VERSION\\\" -DMAKE_AMIGA_DATE=\\\"$(date -u +%d.%m.%Y)\\\""
O="$WORK/obj"
[ "$(cat "$O/.src" 2>/dev/null)" = "$(cat "$SRC/.patched")" ] || { rm -rf "$O"; mkdir -p "$O"; cat "$SRC/.patched" > "$O/.src"; }
M="$O/Makefile"
{
    echo "CF = $CF"
    A=""
    for f in $MAKE_SRCS amiga.c; do
        o="${f%.c}.o"; A="$A $o"
        printf '%s: %s\n\tm68k-amigaos-gcc $(CF) -MMD -c $< -o $@\n' "$o" "$SRC/src/$f"
    done
    for f in $GL_SRCS; do
        o="gl_$(basename "$f" .c).o"; A="$A $o"
        printf '%s: %s\n\tm68k-amigaos-gcc $(CF) -MMD -c $< -o $@\n' "$o" "$SRC/$f"
    done
    # (gnulib's findprog-in and concat-filename serve only job.c's
    # posix_spawn() path, which the Amiga build doesn't have)
    A="$A amiga_glue.o"
    printf 'amiga_glue.o: %s\n\tm68k-amigaos-gcc $(CF) -include %s -c $< -o $@\n' "$HERE/amiga/amiga_glue.c" "$WORK/gen/config.h"
    echo "OBJS =$A"
    echo "all: \$(OBJS)"
    echo "-include *.d"
} > "$M"
(cd "$O" && nice -n 19 make -k -j"$JOBS" all > make.log 2>&1) || { grep -E 'error:' "$O/make.log" | sed 's#^.*/##' | sort | uniq -c | sort -rn | head -150; exit 1; }
echo "compile: $(( $(date +%s) - t0 )) s"

# --- link: soft-float specs, then fpuauto's ----------------------------------------
# shellcheck disable=SC2046
$LINK -o "$O/make.debug" $(cd "$O" && for f in $(sed -n 's/^OBJS =//p' Makefile); do echo "$O/$f"; done) \
    -lm > "$O/link.log" 2>&1 || { head -60 "$O/link.log"; exit 1; }

# --- the GFOpenUp part: Parts/Make --------------------------------------------------
P="$OUT/Parts/Make"; rm -rf "$P"; mkdir -p "$P/C" "$P/Docs/Make"
m68k-amigaos-strip -o "$P/C/make" "$O/make.debug"
cp "$HERE/README.md" "$P/Docs/Make/ReadMe"
cp "$SRC/COPYING" "$P/Docs/Make/COPYING"
cp "$SRC/README.Amiga" "$P/Docs/Make/README.Amiga"
sh "$HERE/scripts/write-part.sh" "$P" "$MAKE_VERSION"
# makefiles for a lab run (not in the part)
rm -rf "$OUT/tests"; mkdir -p "$OUT/tests"
cp "$HERE"/tests/amiga/*.mk "$OUT/tests/"
ls -l "$P/C/make"
echo "part: $(grep -c '^copy' "$P/Part") files, $(du -sk "$P" | cut -f1) KB"
echo "total: $(( $(date +%s) - t0 )) s"
