AM_CPPFLAGS = -I. -I$(top_srcdir)/include -I$(top_builddir)/include -I$(top_builddir)
AM_CFLAGS = -Wall

if ENABLE_PSEUDOTALLOC

# For FreeRTOS builds we only need a static convenience lib; avoid installing or producing a shared object.
noinst_LTLIBRARIES = libpseudotalloc.la

libpseudotalloc_la_SOURCES = pseudotalloc.c pseudotalloc_fallback.c
libpseudotalloc_la_LDFLAGS = -no-undefined -static

nobase_include_HEADERS = talloc.h

endif
