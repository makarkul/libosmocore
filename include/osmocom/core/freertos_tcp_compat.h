/* Minimal FreeRTOS+TCP compatibility socket layer for libosmocore (WIP)
 * Provides a tiny subset of BSD socket style APIs mapped onto FreeRTOS+TCP
 * so higher layers (e.g. future VTY adaptation) can operate without pulling
 * in full POSIX.
 *
 * This is intentionally small: only stream (TCP) server + client basics.
 * We don't attempt to mimic file descriptors beyond returning small ints.
 * No select()/poll() integration yet; a future step will integrate these
 * pseudo-fds with an event loop abstraction.
 */
#pragma once

#ifdef OSMO_FREERTOS

#include <stdint.h>
#include <stddef.h>

#if defined(__has_include)
# if __has_include(<FreeRTOS_Sockets.h>) && __has_include(<FreeRTOS_IP.h>)
#  include <FreeRTOS_IP.h>
#  include <FreeRTOS_Sockets.h>
#  define OSMO_FR_HAVE_FREERTOS_TCP 1
# endif
#endif

#ifdef OSMO_FR_HAVE_FREERTOS_TCP

/* Public API (int is a pseudo-fd index) */
int fr_socket(int domain, int type, int protocol);
int fr_bind(int fd, const char *ip, uint16_t port);
int fr_listen(int fd, int backlog);
int fr_accept(int fd);
int fr_connect(int fd, const char *ip, uint16_t port);
int fr_close(int fd);
int fr_recv(int fd, void *buf, size_t len); /* non-blocking (0 => no data) */
int fr_send(int fd, const void *buf, size_t len); /* returns bytes sent or <0 */

/* Translate pseudo-fd back to underlying Socket_t (debug / advanced) */
Socket_t fr_get_socket(int fd);

#endif /* OSMO_FR_HAVE_FREERTOS_TCP */

#endif /* OSMO_FREERTOS */
