/*! \file talloc.h */
#pragma once

/* Ensure Autoconf defines (OSMO_FREERTOS) are visible even when this header
 * is included before any source file had the chance to include config.h. */
#ifdef HAVE_CONFIG_H
#include "config.h"
#endif

#ifdef OSMO_FREERTOS
/* In FreeRTOS builds we provide a lightweight pseudotalloc in src/pseudotalloc.
 * Use a relative include so we don't need extra -I flags.  The path needs to
 * ascend three levels from include/osmocom/core/ to reach the project root. */
#include "../../../src/pseudotalloc/talloc.h"
#else
#include <talloc.h>
#endif

/*! per-thread talloc contexts.  This works around the problem that talloc is not
 * thread-safe. However, one can simply have a different set of talloc contexts for each
 * thread, and ensure that allocations made on one thread are always only free'd on that
 * very same thread.
 * WARNING: Users must make sure they free() on the same thread as they allocate!! */
struct osmo_talloc_contexts {
	/*! global per-thread talloc context. */
	void *global;
	/*! volatile select-dispatch context.  This context is completely free'd and
	 * re-created every time the main select loop in osmo_select_main() returns from
	 * select(2) and calls per-fd callback functions.  This allows users of this
	 * facility to allocate temporary objects like string buffers, message buffers
	 * and the like which are automatically free'd when going into the next select()
	 * system call */
	void *select;
};

extern __thread struct osmo_talloc_contexts *osmo_ctx;

/* short-hand #defines for the osmo talloc contexts (OTC) that can be used to pass
 * to the various _c functions like msgb_alloc_c() */
#define OTC_GLOBAL (osmo_ctx->global)
#define OTC_SELECT (osmo_ctx->select)

int osmo_ctx_init(const char *id);
