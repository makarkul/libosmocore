/* Minimal FreeRTOS+TCP compatibility socket layer (see header for scope)
 * SPDX-License-Identifier: GPL-2.0+ */

#include "config.h"
#ifdef OSMO_FREERTOS

#include <osmocom/core/freertos_tcp_compat.h>
#include <osmocom/core/logging.h>

#ifndef DLGLOBAL
#define DLGLOBAL 0
#endif

#ifdef OSMO_FR_HAVE_FREERTOS_TCP

/* Simple static table mapping pseudo-fd -> Socket_t */
#define FR_MAX_SOCKETS 16
struct fr_sock_entry {
    Socket_t sock;
    int used;
};
static struct fr_sock_entry g_sock_tbl[FR_MAX_SOCKETS];
static int g_next_fd_base = 1000; /* start pseudo-fds at high range */

static int alloc_slot(void) {
    for (int i = 0; i < FR_MAX_SOCKETS; ++i) {
        if (!g_sock_tbl[i].used) {
            g_sock_tbl[i].used = 1;
            g_sock_tbl[i].sock = FREERTOS_INVALID_SOCKET;
            return g_next_fd_base + i;
        }
    }
    return -1;
}

static void free_slot(int fd) {
    int idx = fd - g_next_fd_base;
    if (idx < 0 || idx >= FR_MAX_SOCKETS) return;
    g_sock_tbl[idx].used = 0;
    g_sock_tbl[idx].sock = FREERTOS_INVALID_SOCKET;
}

static Socket_t *fd_to_sock(int fd) {
    int idx = fd - g_next_fd_base;
    if (idx < 0 || idx >= FR_MAX_SOCKETS) return NULL;
    if (!g_sock_tbl[idx].used) return NULL;
    return &g_sock_tbl[idx].sock;
}

Socket_t fr_get_socket(int fd) {
    Socket_t *p = fd_to_sock(fd);
    return p ? *p : FREERTOS_INVALID_SOCKET;
}

int fr_socket(int domain, int type, int protocol) {
    (void)domain; (void)protocol; /* Only AF_INET, TCP supported */
    if (type != FREERTOS_SOCK_STREAM)
        return -1;
    int fd = alloc_slot();
    if (fd < 0)
        return -1;
    Socket_t *s = fd_to_sock(fd);
    *s = FreeRTOS_socket(FREERTOS_AF_INET, FREERTOS_SOCK_STREAM, FREERTOS_IPPROTO_TCP);
    if (*s == FREERTOS_INVALID_SOCKET) {
        free_slot(fd);
        return -1;
    }
    return fd;
}

int fr_bind(int fd, const char *ip, uint16_t port) {
    Socket_t *s = fd_to_sock(fd);
    if (!s || *s == FREERTOS_INVALID_SOCKET) return -1;
    struct freertos_sockaddr addr = {0};
    addr.sin_port = FreeRTOS_htons(port);
    if (ip && ip[0]) {
        uint32_t a = FreeRTOS_inet_addr(ip);
        if (a == 0 && ip[0] != '0') return -1;
        addr.sin_addr = a;
    }
    if (FreeRTOS_bind(*s, &addr, sizeof(addr)) != 0) return -1;
    return 0;
}

int fr_listen(int fd, int backlog) {
    (void)backlog; /* FreeRTOS_listen ignores backlog, uses internal config */
    Socket_t *s = fd_to_sock(fd);
    if (!s || *s == FREERTOS_INVALID_SOCKET) return -1;
    if (FreeRTOS_listen(*s, backlog <= 0 ? 1 : backlog) != 0) return -1;
    return 0;
}

int fr_accept(int fd) {
    Socket_t *s = fd_to_sock(fd);
    if (!s || *s == FREERTOS_INVALID_SOCKET) return -1;
    struct freertos_sockaddr from; socklen_t fromlen = sizeof(from);
    Socket_t ns = FreeRTOS_accept(*s, &from, &fromlen);
    if (ns == FREERTOS_INVALID_SOCKET)
        return -1;
    int nfd = alloc_slot();
    if (nfd < 0) {
        FreeRTOS_closesocket(ns);
        return -1;
    }
    Socket_t *slot = fd_to_sock(nfd);
    *slot = ns;
    return nfd;
}

int fr_connect(int fd, const char *ip, uint16_t port) {
    Socket_t *s = fd_to_sock(fd);
    if (!s || *s == FREERTOS_INVALID_SOCKET) return -1;
    struct freertos_sockaddr addr = {0};
    addr.sin_port = FreeRTOS_htons(port);
    uint32_t a = FreeRTOS_inet_addr(ip);
    if (a == 0 && ip[0] != '0') return -1;
    addr.sin_addr = a;
    BaseType_t rc = FreeRTOS_connect(*s, &addr, sizeof(addr));
    if (rc != 0) return -1;
    return 0;
}

int fr_close(int fd) {
    Socket_t *s = fd_to_sock(fd);
    if (!s) return -1;
    if (*s != FREERTOS_INVALID_SOCKET)
        FreeRTOS_closesocket(*s);
    free_slot(fd);
    return 0;
}

int fr_recv(int fd, void *buf, size_t len) {
    Socket_t *s = fd_to_sock(fd);
    if (!s || *s == FREERTOS_INVALID_SOCKET) return -1;
    BaseType_t r = FreeRTOS_recv(*s, buf, len, FREERTOS_MSG_DONTWAIT);
    if (r < 0) return -1;
    return (int)r;
}

int fr_send(int fd, const void *buf, size_t len) {
    Socket_t *s = fd_to_sock(fd);
    if (!s || *s == FREERTOS_INVALID_SOCKET) return -1;
    BaseType_t r = FreeRTOS_send(*s, buf, len, 0);
    if (r < 0) return -1;
    return (int)r;
}

#endif /* OSMO_FR_HAVE_FREERTOS_TCP */

#endif /* OSMO_FREERTOS */
