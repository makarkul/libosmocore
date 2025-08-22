/* FreeRTOS socket shim (early WIP)
 * Minimal API surface to satisfy libosmocore builds when OSMO_FREERTOS is defined.
 * When FreeRTOS+TCP headers are available, wrappers map to its API; otherwise stubs.
 */
#pragma once

#ifdef OSMO_FREERTOS

#include <stdint.h>
#include <stddef.h>

/* Attempt to detect FreeRTOS+TCP headers (GCC/Clang). */
#if defined(__has_include)
# if __has_include(<FreeRTOS_Sockets.h>) && __has_include(<FreeRTOS_IP.h>)
#  define OSMO_FR_HAVE_FREERTOS_TCP 1
# endif
#endif

#ifdef OSMO_FR_HAVE_FREERTOS_TCP
# include <FreeRTOS_IP.h>
# include <FreeRTOS_Sockets.h>
typedef Socket_t osmo_fr_socket_t;
#else
typedef int osmo_fr_socket_t; /* Fallback placeholder */
#endif

/* Minimal constants */
#ifndef OSMO_FR_INVALID_SOCKET
#define OSMO_FR_INVALID_SOCKET (-1)
#endif

/* Shim function prototypes */
int osmo_fr_socket_create_udp(osmo_fr_socket_t *sock, uint16_t local_port);
int osmo_fr_socket_sendto(osmo_fr_socket_t sock, const void *buf, size_t len,
                          const char *remote_ip, uint16_t remote_port);
int osmo_fr_socket_recvfrom(osmo_fr_socket_t sock, void *buf, size_t len,
                            char *remote_ip, size_t remote_ip_len,
                            uint16_t *remote_port, int block_ms);
int osmo_fr_socket_close(osmo_fr_socket_t sock);

#endif /* OSMO_FREERTOS */
