/* GNU Make on GFOS: its stack (the Shell's 4 KB is too small for make's
 * recursion through rules and variables), the $VER string, and the load
 * average (AmigaOS keeps none: -l is "unsupported", as job.c expects when
 * getloadavg fails with errno 0).
 * MIT, Copyright (c) 2026 AmiCradle Team. */
#include <errno.h>

unsigned long __stack = 128 * 1024;
static const char version[] __attribute__((used)) = "$VER: make " MAKE_AMIGA_VERSION " (" MAKE_AMIGA_DATE ") GFOS";

#ifndef HAVE_GETLOADAVG
int getloadavg(double loadavg[], int nelem)
{
	(void)loadavg; (void)nelem;
	errno = 0;
	return -1;
}
#endif
