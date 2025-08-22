/* Fallback weak implementations for pseudotalloc environment hooks.
 * If the embedding application doesn't provide pseudotalloc_malloc/free,
 * fall back to malloc/free so builds/link tests succeed. On constrained
 * targets, provide your own versions instead.
 */
#include <stdlib.h>
#include "talloc.h"

__attribute__((weak)) void *pseudotalloc_malloc(size_t size)
{
    return malloc(size);
}

__attribute__((weak)) void pseudotalloc_free(void *ptr)
{
	free(ptr);
}
