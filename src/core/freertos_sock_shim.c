/* FreeRTOS socket shim implementation (UDP subset)
 * SPDX-License-Identifier: GPL-2.0+ */

#include "config.h"
#ifdef OSMO_FREERTOS

/* NOTE: We intentionally avoid including heavy kernel headers if FreeRTOS+TCP
 * isn't present; in that case these remain stubs returning -1. */

#include <osmocom/core/freertos_sock_shim.h>
#include <osmocom/core/logging.h>

#ifndef DLGLOBAL
#define DLGLOBAL 0
#endif

#ifdef OSMO_FR_HAVE_FREERTOS_TCP

int osmo_fr_socket_create_udp(osmo_fr_socket_t *sock, uint16_t local_port)
{
    struct freertos_sockaddr addr = { 0 };
    *sock = FreeRTOS_socket(FREERTOS_AF_INET, FREERTOS_SOCK_DGRAM, FREERTOS_IPPROTO_UDP);
    if (*sock == FREERTOS_INVALID_SOCKET) {
        LOGP(DLGLOBAL, LOGL_ERROR, "[freertos_sock_shim] FreeRTOS_socket failed\n");
        return -1;
    }
    addr.sin_port = FreeRTOS_htons(local_port);
    if (FreeRTOS_bind(*sock, &addr, sizeof(addr)) != 0) {
        LOGP(DLGLOBAL, LOGL_ERROR, "[freertos_sock_shim] FreeRTOS_bind failed port=%u\n", local_port);
        FreeRTOS_closesocket(*sock);
        *sock = FREERTOS_INVALID_SOCKET;
        return -1;
    }
    return 0;
}

int osmo_fr_socket_sendto(osmo_fr_socket_t sock, const void *buf, size_t len,
                          const char *remote_ip, uint16_t remote_port)
{
    struct freertos_sockaddr to = { 0 };
    uint32_t ip = FreeRTOS_inet_addr(remote_ip);
    if (ip == 0 && remote_ip[0] != '0') {
        LOGP(DLGLOBAL, LOGL_ERROR, "[freertos_sock_shim] inet_addr failed for %s\n", remote_ip);
        return -1;
    }
    to.sin_port = FreeRTOS_htons(remote_port);
    to.sin_addr = ip;
    BaseType_t sent = FreeRTOS_sendto(sock, buf, len, 0, &to, sizeof(to));
    if (sent < 0) {
        LOGP(DLGLOBAL, LOGL_ERROR, "[freertos_sock_shim] sendto failed rc=%ld\n", (long)sent);
        return -1;
    }
    return (int)sent;
}

int osmo_fr_socket_recvfrom(osmo_fr_socket_t sock, void *buf, size_t len,
                            char *remote_ip, size_t remote_ip_len,
                            uint16_t *remote_port, int block_ms)
{
    struct freertos_sockaddr from;
    socklen_t fromlen = sizeof(from);
    TickType_t ticks = block_ms < 0 ? portMAX_DELAY : (block_ms / portTICK_PERIOD_MS);
    FreeRTOS_setsockopt(sock, 0, FREERTOS_SO_RCVTIMEO, &ticks, sizeof(ticks));
    BaseType_t r = FreeRTOS_recvfrom(sock, buf, len, 0, &from, &fromlen);
    if (r < 0) return -1;
    if (remote_port) *remote_port = FreeRTOS_ntohs(from.sin_port);
    if (remote_ip && remote_ip_len) {
        const char *ipstr = FreeRTOS_inet_ntoa(from.sin_addr);
        if (ipstr) {
            /* Simple bounded copy */
            size_t i; for (i = 0; i + 1 < remote_ip_len && ipstr[i]; ++i) remote_ip[i] = ipstr[i];
            remote_ip[i] = '\0';
        } else if (remote_ip_len) {
            remote_ip[0] = '\0';
        }
    }
    return (int)r;
}

int osmo_fr_socket_close(osmo_fr_socket_t sock)
{
    if (sock == FREERTOS_INVALID_SOCKET)
        return 0;
    if (FreeRTOS_closesocket(sock) != 0) {
        LOGP(DLGLOBAL, LOGL_ERROR, "[freertos_sock_shim] closesocket failed\n");
        return -1;
    }
    return 0;
}

#else /* !OSMO_FR_HAVE_FREERTOS_TCP */

int osmo_fr_socket_create_udp(osmo_fr_socket_t *sock, uint16_t local_port)
{
    (void)local_port; *sock = OSMO_FR_INVALID_SOCKET; return -1;
}
int osmo_fr_socket_sendto(osmo_fr_socket_t sock, const void *buf, size_t len,
                          const char *remote_ip, uint16_t remote_port)
{
    (void)sock; (void)buf; (void)len; (void)remote_ip; (void)remote_port; return -1;
}
int osmo_fr_socket_recvfrom(osmo_fr_socket_t sock, void *buf, size_t len,
                            char *remote_ip, size_t remote_ip_len,
                            uint16_t *remote_port, int block_ms)
{
    (void)sock; (void)buf; (void)len; (void)remote_ip; (void)remote_ip_len; (void)remote_port; (void)block_ms; return -1;
}
int osmo_fr_socket_close(osmo_fr_socket_t sock)
{
    (void)sock; return 0;
}

#endif /* OSMO_FR_HAVE_FREERTOS_TCP */

#endif /* OSMO_FREERTOS */
