# GNU Make for GFOS

GNU Make 4.4.1 for GFOS (AmigaOS 3.2.3 with GFOpenUp), as a GFOpenUp part:

    GFOpenUpTool INSTALL Parts/Make

gives `C:make` and `SYS:Docs/Make/` (this ReadMe, GNU Make's licence and
upstream's README.Amiga).

    make                      the makefile in the current directory
    make -f Build.mk target
    make -n                   show the commands without running them

## What it is

- GNU Make 4.4.1 from the GitHub mirror of Savannah's make.git at tag
  4.4.1, with the gnulib files it needs at stable-202301 (make.lock),
  fetched at build time; nothing third-party is kept here.
- Upstream's own Amiga code (`src/amiga.c`): recipes run in the Shell
  through `SystemTags()`, so recipe lines are AmigaDOS commands (`Copy`,
  `Delete`, `Echo`), and `$(wildcard)` takes AmigaDOS paths (`Work:src/*.c`).
  `$(dir)` and `$(notdir)` know the `DEVICE:` part of a path.
- 68040, soft float with fpuauto; 128 KB stack set in the program.
- One job at a time: `-j` is accepted and runs jobs in turn (no jobserver,
  no `--output-sync` on AmigaOS). No `$(load)` modules, no Guile.
- `$VER` gives the release's version; upstream's 1996 port string is
  removed (patches/0001).

## Build

    STOVE=.../stoves/os32-gcc16-open6 OUT=out ./build-amiga.sh

The PC tests run first. `OUT/Parts/Make` is the part; `OUT/tests` holds two
makefiles for a lab run:

    make -f funcs.mk                                  funcs: all 29 checks passed
    make -f recipes.mk clean
    make -f recipes.mk check                          recipes: passed

## Tests

    make -C tests test

- `test-part.sh`: the Part file.
- `host-make.sh`: Make built for the PC from the same sources and gnulib,
  then upstream's own test suite (`tests/run_make_tests.pl`, 1390 cases),
  then `tests/amiga/funcs.mk`. Three tests need a user other than root
  (`tests/root-skips.txt`) and are left out only when run as root.

MIT (this repository); GNU Make is GPL 3, Copyright (C) 1988-2023 Free
Software Foundation, Inc.; the gnulib files are LGPL 2.1 or later.

Team 3
