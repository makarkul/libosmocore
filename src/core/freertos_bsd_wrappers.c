/* BSD-style socket API wrappers for FreeRTOS+TCP.
 * Option 1 implementation: provide real symbols socket/bind/listen/accept/connect/close/recv/send
 * so existing libosmocore + VTY code links unchanged under OSMO_FREERTOS.
 * Limited scope: AF_INET, SOCK_STREAM only. Others return -1 / EAFNOSUPPORT.
 * SPDX-License-Identifier: GPL-2.0+ */

#include "config.h"
#ifdef OSMO_FREERTOS

#include <errno.h>
#include <string.h>
#include <stdint.h>
#include <osmocom/core/freertos_tcp_compat.h>
#include <osmocom/core/logging.h>

#include <stdio.h>
#include <sys/types.h>

/* Provide minimal errno mapping */
static int map_fail(void) { errno = EINVAL; return -1; }

/* Always export symbols under OSMO_FREERTOS; internally select implementation. */
int socket(int domain, int type, int protocol)
{
#ifdef OSMO_FR_HAVE_FREERTOS_TCP
    if (domain != 2 /* AF_INET */) return map_fail();
    /* Support stream + datagram */
    if (type == 1) /* SOCK_STREAM */
        return fr_socket(domain, FREERTOS_SOCK_STREAM, protocol);
    if (type == 2) /* SOCK_DGRAM */ {
        /* Re-use UDP creation from shim if desired later; for now reject */
        return map_fail();
    }
    return map_fail();
#else
    return map_fail();
#endif
}

int bind(int fd, const void *addr, unsigned int addrlen)
{
    (void)addrlen;
#ifdef OSMO_FR_HAVE_FREERTOS_TCP
    if (!fr_is_pseudo_fd(fd)) return map_fail();
    const uint8_t *b = (const uint8_t*)addr;
    uint16_t port_net = (uint16_t)(b[2] << 8 | b[3]);
    uint32_t ip = (uint32_t)(b[4] | (b[5]<<8) | (b[6]<<16) | (b[7]<<24));
    char ipbuf[16];
    snprintf(ipbuf, sizeof(ipbuf), "%u.%u.%u.%u",
             (unsigned)(ip & 0xFF), (unsigned)((ip>>8)&0xFF),
             (unsigned)((ip>>16)&0xFF), (unsigned)((ip>>24)&0xFF));
    /* Convert big-endian network port */
    uint16_t port_host = (uint16_t)((port_net>>8)|((port_net&0xFF)<<8));
    return fr_bind(fd, ip ? ipbuf : NULL, port_host);
#else
    return map_fail();
#endif
}

int listen(int fd, int backlog)
{
#ifdef OSMO_FR_HAVE_FREERTOS_TCP
    if (!fr_is_pseudo_fd(fd)) return map_fail();
    return fr_listen(fd, backlog);
#else
    return map_fail();
#endif
}

int accept(int fd, void *addr, unsigned int *addrlen)
{
    (void)addr; (void)addrlen;
#ifdef OSMO_FR_HAVE_FREERTOS_TCP
    if (!fr_is_pseudo_fd(fd)) return map_fail();
    return fr_accept(fd);
#else
    return map_fail();
#endif
}

int connect(int fd, const void *addr, unsigned int addrlen)
{
    (void)addrlen;
#ifdef OSMO_FR_HAVE_FREERTOS_TCP
    if (!fr_is_pseudo_fd(fd)) return map_fail();
    const uint8_t *b = (const uint8_t*)addr;
    uint16_t port_net = (uint16_t)(b[2] << 8 | b[3]);
    uint32_t ip = (uint32_t)(b[4] | (b[5]<<8) | (b[6]<<16) | (b[7]<<24));
    char ipbuf[16];
    snprintf(ipbuf, sizeof(ipbuf), "%u.%u.%u.%u",
             (unsigned)(ip & 0xFF), (unsigned)((ip>>8)&0xFF),
             (unsigned)((ip>>16)&0xFF), (unsigned)((ip>>24)&0xFF));
    uint16_t port_host = (uint16_t)((port_net>>8)|((port_net&0xFF)<<8));
    return fr_connect(fd, ipbuf, port_host);
#else
    return map_fail();
#endif
}

int close(int fd)
{
#ifdef OSMO_FR_HAVE_FREERTOS_TCP
    if (!fr_is_pseudo_fd(fd)) return 0; /* treat as already closed */
    return fr_close(fd);
#else
    return 0;
#endif
}

ssize_t recv(int fd, void *buf, size_t len, int flags)
{
    (void)flags;
#ifdef OSMO_FR_HAVE_FREERTOS_TCP
    return fr_recv(fd, buf, len);
#else
    errno = EAGAIN; return -1;
#endif
}

ssize_t send(int fd, const void *buf, size_t len, int flags)
{
    (void)flags;
#ifdef OSMO_FR_HAVE_FREERTOS_TCP
    return fr_send(fd, buf, len);
#else
    errno = EPIPE; return -1;
#endif
}

#endif /* OSMO_FREERTOS */
