# What build-amiga.sh (the stove) and tests/host-make.sh (the PC) share:
# GNU Make's sources, the gnulib files it needs, and the config.h its
# configure would write. Sourced; needs HERE (the repo) and make.lock's
# settings.
# MIT, Copyright (c) 2026 AmiCradle Team.

# GNU Make's program, as upstream's Makefile.am (make_SRCS, remote-stub)
MAKE_SRCS="ar.c arscan.c commands.c default.c dir.c expand.c file.c function.c
 getopt.c getopt1.c guile.c hash.c implicit.c job.c load.c loadapi.c main.c
 misc.c output.c read.c remake.c rule.c shuffle.c signame.c strcache.c
 variable.c version.c vpath.c remote-stub.c"
# gnulib's: Make's own glob and fnmatch (gl/lib), findprog-in, concat-filename
GL_SRCS="gl/lib/glob.c gl/lib/fnmatch.c"
GNULIB_SRCS="findprog-in.c concat-filename.c"
GNULIB_HDRS="intprops.h intprops-internal.h findprog.h concat-filename.h filename.h"

# a repository at one commit, fetched once: fetch_at DIR URL COMMIT [SPARSE]
fetch_at() {
    if [ "$(git -C "$1" rev-parse HEAD 2>/dev/null)" != "$3" ]; then
        rm -rf "${1:?}"; mkdir -p "$1"
        git -C "$1" init -q
        if [ -n "${4:-}" ]; then
            git -C "$1" config core.sparseCheckout true
            echo "$4" > "$1/.git/info/sparse-checkout"
            git -C "$1" fetch -q --depth 1 --filter=blob:none "$2" "$3"
        else
            git -C "$1" fetch -q --depth 1 "$2" "$3"
        fi
        git -C "$1" checkout -q FETCH_HEAD
        [ "$(git -C "$1" rev-parse HEAD)" = "$3" ] || { echo "$1: commit mismatch"; exit 1; }
    fi
}

# Make at MAKE_COMMIT with patches/ applied, into $1; gnulib's lib/ into $2
mk_source() {
    PSUM=$(cat "$HERE"/patches/*.patch 2>/dev/null | sha256sum | cut -c1-16)
    if [ "$(cat "$1/.patched" 2>/dev/null)" != "$MAKE_COMMIT-$PSUM" ]; then
        rm -rf "$1"
        fetch_at "$1" "$MAKE_GIT" "$MAKE_COMMIT"
        for p in "$HERE"/patches/*.patch; do
            [ -f "$p" ] || continue
            patch -s -d "$1" -p1 < "$p" || { echo "patch failed: $p"; exit 1; }
        done
        echo "$MAKE_COMMIT-$PSUM" > "$1/.patched"
    fi
    fetch_at "$2" "$GNULIB_GIT" "$GNULIB_COMMIT" "/lib/"
}

# The generated headers into $3 (a directory): mkconfig.h from Make's
# mkconfig.h.in, glob.h and fnmatch.h, gnulib's headers, and config.h:
# each function counts when it links AND a header declares it, each
# header when it compiles ($PROBE_CC: compile and link command), then
# what the platform ($2: pc or gfos) needs. $1 is Make's tree, $4 gnulib's.
mk_config() {
    D=$3; mkdir -p "$D"
    sed -e 's/@PACKAGE@/make/' -e 's/@PACKAGE_BUGREPORT@/bug-make@gnu.org/' \
        -e 's/@PACKAGE_NAME@/GNU make/g' -e 's/@PACKAGE_TARNAME@/make/' \
        -e 's|@PACKAGE_URL@|https://www.gnu.org/software/make/|' \
        -e "s/@PACKAGE_VERSION@/$MAKE_VERSION/g" "$1/src/mkconfig.h.in" > "$D/mkconfig.h"
    cp "$1/gl/lib/glob.in.h" "$D/glob.h"; cp "$1/gl/lib/fnmatch.in.h" "$D/fnmatch.h"
    for h in $GNULIB_HDRS; do cp "$4/lib/$h" "$D/$h"; done
    t=$(mktemp -d)
    {
        echo "/* config.h: written by scripts/mk-common.sh mk_config ($2) */"
        echo "#include \"mkconfig.h\""
        echo "#ifndef _GNU_SOURCE"
        echo "#define _GNU_SOURCE 1"
        echo "#endif"
        echo "#define STDC_HEADERS 1"
        for h in unistd.h stdlib.h string.h strings.h limits.h fcntl.h dirent.h \
                 sys/wait.h sys/time.h sys/param.h sys/resource.h sys/select.h \
                 sys/file.h sys/timeb.h inttypes.h stdint.h locale.h alloca.h memory.h; do
            printf '#include <%s>\nint main(void) { return 0; }\n' "$h" > "$t/p.c"
            # shellcheck disable=SC2086
            if $PROBE_CC -o "$t/p" "$t/p.c" > /dev/null 2>&1; then
                echo "#define HAVE_$(echo "$h" | tr '[:lower:]/.' '[:upper:]__') 1"
            fi
        done
        for f in atexit dup dup2 fdopen getcwd gettimeofday clock_gettime isatty \
                 ttyname memrchr mempcpy stpcpy strdup strndup strcasecmp strncasecmp \
                 strsignal strtoll mkstemp mktemp umask waitpid wait3 sigaction setvbuf \
                 getrlimit setrlimit pselect mkfifo realpath strcoll strftime memmove \
                 setlinebuf sigsetmask getloadavg; do
            printf '%s\n' '#define _GNU_SOURCE 1' '#include <stdio.h>' '#include <stdlib.h>' \
                '#include <string.h>' '#include <strings.h>' '#include <unistd.h>' \
                '#include <time.h>' '#include <signal.h>' '#include <sys/types.h>' \
                '#include <sys/stat.h>' > "$t/p.c"
            for h in sys/wait.h sys/time.h sys/resource.h sys/select.h; do
                printf '#include <%s>\nint main(void) { return 0; }\n' "$h" > "$t/h.c"
                # shellcheck disable=SC2086
                if $PROBE_CC -o "$t/h" "$t/h.c" > /dev/null 2>&1; then echo "#include <$h>" >> "$t/p.c"; fi
            done
            printf 'int main(void) { void (*volatile p)(void) = (void (*)(void))%s; return p != 0; }\n' "$f" >> "$t/p.c"
            # shellcheck disable=SC2086
            if $PROBE_CC -o "$t/p" "$t/p.c" -lm > /dev/null 2>&1; then
                echo "#define HAVE_$(echo "$f" | tr '[:lower:]' '[:upper:]') 1"
            fi
        done
        echo "#define HAVE_ALLOCA 1"
        echo "#ifndef HAVE_ALLOCA_H"
        echo "#define alloca __builtin_alloca"
        echo "#endif"
        echo "#define SCCS_GET \"get\""
        echo "#define RETSIGTYPE void"
        echo "#define HAVE_DECL_SYS_SIGLIST 0"
        echo "#define HAVE_DECL__SYS_SIGLIST 0"
        echo "#define HAVE_DECL___SYS_SIGLIST 0"
        echo "#define HAVE_DECL_BSD_SIGNAL 0"
        echo "#define HAVE_DECL_PROGRAM_INVOCATION_NAME 0"
        echo "#define USE_POSIX_SPAWN 0"
        case $2 in
        pc)
            echo "#define MAKE_HOST \"$(uname -m)-pc-$(uname -s | tr '[:upper:]' '[:lower:]')-gnu\""
            echo "#define MAKE_JOBSERVER 1"
            echo "#define MAKE_SYMLINKS 1"
            echo "#define HAVE_SA_RESTART 1"
            echo "#define HAVE_STRUCT_DIRENT_D_TYPE 1"
            echo "#define FILE_TIMESTAMP_HI_RES 1"
            echo "#define ST_MTIM_NSEC st_mtim.tv_nsec"
            echo "#define HAVE_DECL_GETLOADAVG 1"
            echo "#define PATH_SEPARATOR_CHAR ':'"
            ;;
        gfos)
            echo "/* GFOS: upstream's Amiga code (src/amiga.c: commands through"
            echo "   SystemTags() and the user's Shell, AmigaDOS wildcards), no"
            echo "   jobserver or output sync, names case-insensitive as on"
            echo "   AmigaDOS; vpath and VPATH entries split on ';', since ':' ends"
            echo "   a volume name (Work:src) */"
            echo "#define _AMIGA 1"
            echo "#define MK_AMIGAOS 1"
            echo "#define MAKE_HOST \"m68k-amigaos-gfos\""
            echo "#define NO_OUTPUT_SYNC 1"
            echo "#define HAVE_CASE_INSENSITIVE_FS 1"
            echo "#define PATH_SEPARATOR_CHAR ';'"
            echo "#define HAVE_DECL_GETLOADAVG 0   /* job.c declares it; amiga/amiga_glue.c */"
            ;;
        esac
        echo "/* what gnulib's own headers expect from its configure */"
        echo "#include <stdbool.h>"
        echo "#define _GL_ATTRIBUTE_MALLOC __attribute__ ((__malloc__))"
        echo "#define _GL_ATTRIBUTE_DEALLOC_FREE"
        echo "#define _GL_ATTRIBUTE_DEALLOC(f, i)"
        echo "#define _GL_ATTRIBUTE_PURE __attribute__ ((__pure__))"
        echo "#define _GL_ATTRIBUTE_CONST __attribute__ ((__const__))"
        echo "#define _GL_ATTRIBUTE_NODISCARD"
        echo "#define _GL_ATTRIBUTE_RETURNS_NONNULL __attribute__ ((__returns_nonnull__))"
        echo "#define _GL_UNUSED __attribute__ ((__unused__))"
    } > "$D/config.h"
    rm -rf "$t"
}
