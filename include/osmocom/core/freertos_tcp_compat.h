/* Minimal FreeRTOS+TCP compatibility + BSD wrapper layer for OSMO_FREERTOS
 * Always expose a consistent tiny API surface. If FreeRTOS+TCP headers are
 * unavailable, functions return failure (typically -1) so higher layers can
 * decide to disable runtime features gracefully. */

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
typedef Socket_t osmo_fr_socket_t;
#else
typedef int Socket_t; /* placeholder */
typedef int osmo_fr_socket_t;
#endif

#ifndef OSMO_FR_INVALID_SOCKET
#define OSMO_FR_INVALID_SOCKET (-1)
#endif

/* UDP subset */
int osmo_fr_socket_create_udp(osmo_fr_socket_t *sock, uint16_t local_port);
int osmo_fr_socket_sendto(osmo_fr_socket_t sock, const void *buf, size_t len,
						  const char *remote_ip, uint16_t remote_port);
int osmo_fr_socket_recvfrom(osmo_fr_socket_t sock, void *buf, size_t len,
							char *remote_ip, size_t remote_ip_len,
							uint16_t *remote_port, int block_ms);
int osmo_fr_socket_close(osmo_fr_socket_t sock);

/* Stream (TCP) pseudo-fd layer */
int fr_is_pseudo_fd(int fd);
int fr_socket(int domain, int type, int protocol);
int fr_bind(int fd, const char *ip, uint16_t port);
int fr_listen(int fd, int backlog);
int fr_accept(int fd);
int fr_connect(int fd, const char *ip, uint16_t port);
int fr_close(int fd);
int fr_recv(int fd, void *buf, size_t len);   /* non-blocking semantics (0 = no data) */
int fr_send(int fd, const void *buf, size_t len);
Socket_t fr_get_socket(int fd);

#endif /* OSMO_FREERTOS */
