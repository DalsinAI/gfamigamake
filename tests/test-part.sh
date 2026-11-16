#!/bin/sh
# PC test for scripts/write-part.sh: the Part file GFOpenUpTool reads.
# MIT, Copyright (c) 2026 AmiCradle Team.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
mkdir -p "$T/C" "$T/Docs/Make"
: > "$T/C/make"; : > "$T/Docs/Make/ReadMe"; : > "$T/Docs/Make/COPYING"
sh "$HERE/../scripts/write-part.sh" "$T" 4.4.1
fail=0
expect() { grep -qxF "$1" "$T/Part" || { echo "FAIL: no line: $1"; fail=1; }; }
expect 'part Make 4.4.1'
expect 'needs 68040'
expect 'copy "C/make" "SYS:C/make"'
expect 'copy "Docs/Make/ReadMe" "SYS:Docs/Make/ReadMe"'
expect 'copy "Docs/Make/COPYING" "SYS:Docs/Make/COPYING"'
[ "$(head -1 "$T/Part")" = 'part Make 4.4.1' ] || { echo "FAIL: first line"; fail=1; }
[ "$(grep -c '^copy' "$T/Part")" = 3 ] || { echo "FAIL: file count (the Part file itself must not be listed)"; fail=1; }
sh "$HERE/../scripts/write-part.sh" "$T" 4.4.1
[ "$(grep -c '^copy' "$T/Part")" = 3 ] || { echo "FAIL: second run lists the Part file"; fail=1; }
[ $fail = 0 ] && echo "Part file: all checks passed"
exit $fail
