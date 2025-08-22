/* Portable detection of sys/socket.h without relying on substituted XX macro.
 * We prefer compile-time __has_include. If unavailable, assume presence on
 * hosted (not freestanding) environments unless OSMO_FREERTOS set. */

#if defined(__has_include)
# if __has_include(<sys/socket.h>)
#  define _OSMO_HAVE_SYS_SOCKET 1
# endif
#endif

#if defined(OSMO_FREERTOS) && !defined(_OSMO_HAVE_SYS_SOCKET)
/* On real FreeRTOS targets we expect no sys/socket.h, provide fallback. */
struct sockaddr_storage {
	unsigned short ss_family;
	char __data[128 - sizeof(unsigned short)];
};
#elif defined(_OSMO_HAVE_SYS_SOCKET)
# include <sys/socket.h>
#else
/* Conservative fallback if detection failed (e.g. compiler lacks __has_include)
 * and we're in an unusual freestanding environment. */
struct sockaddr_storage {
	unsigned short ss_family;
	char __data[128 - sizeof(unsigned short)];
};
#endif
