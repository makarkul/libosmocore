/*! \file pseudotalloc_test_stub.c
 * Test stub providing pseudotalloc_malloc/free implementations for FreeRTOS test binaries.
 * Simple fallback to standard malloc/free for test purposes.
 * 
 * This file provides the required pseudotalloc_malloc and pseudotalloc_free functions
 * that the pseudotalloc library expects but doesn't provide itself. For test purposes,
 * we simply use standard malloc/free.
 */

#include <stdlib.h>

void *pseudotalloc_malloc(size_t size)
{
    return malloc(size);
}

void pseudotalloc_free(void *ptr)
{
    if (ptr)
        free(ptr);
}