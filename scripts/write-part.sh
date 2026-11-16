#!/bin/sh
# Writes the Part file GFOpenUpTool INSTALL reads (gfopenup src/openuptool.c)
# for the part drawer the build made: C/make to C:make, Docs/Make/ to
# SYS:Docs/Make/.
#   write-part.sh <part drawer> <version>
# MIT, Copyright (c) 2026 AmiCradle Team.
set -eu
P=$1; V=$2
{
    echo "part Make $V"
    echo "; GNU Make (C:make): builds programs from makefiles, commands run in the Shell"
    echo "needs 68040"
    (cd "$P" && find C Docs -type f | LC_ALL=C sort) | while read -r f; do
        echo "copy \"$f\" \"SYS:$f\""
    done
} > "$P/Part"
