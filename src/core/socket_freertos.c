/* Minimal FreeRTOS replacements for osmo_sock_* when sys/socket.h absent.
 * This keeps original socket.c untouched; compiled only with --enable-freertos
 * where we force HAVE_SYS_SOCKET_H=0 in configure.ac. We implement only
 * UDP datagram helpers needed early (gsmtap, stats). Others return -1 ENOTSUP.
 * SPDX-License-Identifier: GPL-2.0+ */

#include "config.h"

#if defined(OSMO_FREERTOS) && !HAVE_SYS_SOCKET_H

#include <errno.h>
#include <string.h>
#include <osmocom/core/logging.h>
#include <osmocom/core/socket.h>
#include <osmocom/core/freertos_sock_shim.h>

#ifndef DLGLOBAL
#define DLGLOBAL 0
#endif

static int freertos_check_udp(uint16_t type, uint8_t proto)
{
    if (type != SOCK_DGRAM || proto != IPPROTO_UDP)
        return -1;
    return 0;
}

int osmo_sock_init(uint16_t family, uint16_t type, uint8_t proto,
                   const char *host, uint16_t port, unsigned int flags)
{
    (void)family; (void)flags; /* Only IPv4 UDP currently */
    if (freertos_check_udp(type, proto) < 0) {
        errno = ENOTSUP; return -1;
    }
    osmo_fr_socket_t sock;
    if (osmo_fr_socket_create_udp(&sock, 0) != 0)
        return -1;
    /* If connect requested, we can't emulate yet; store remote and send via shim on each send later (TODO). */
    (void)host; (void)port;
    return (int)sock;
}

int osmo_sock_init2(uint16_t family, uint16_t type, uint8_t proto,
                    const char *local_host, uint16_t local_port,
                    const char *remote_host, uint16_t remote_port, unsigned int flags)
{
    (void)family; (void)local_host; (void)remote_host; (void)remote_port; (void)flags;
    if (freertos_check_udp(type, proto) < 0) { errno = ENOTSUP; return -1; }
    osmo_fr_socket_t sock;
    if (osmo_fr_socket_create_udp(&sock, local_port) != 0)
        return -1;
    /* Remote association stored externally by user; for now we ignore remote params. */
    return (int)sock;
}

int osmo_sock_init_sa(struct sockaddr *ss, uint16_t type,
                      uint8_t proto, unsigned int flags)
{
    (void)ss; (void)flags;
    if (freertos_check_udp(type, proto) < 0) { errno = ENOTSUP; return -1; }
    osmo_fr_socket_t sock;
    if (osmo_fr_socket_create_udp(&sock, 0) != 0)
        return -1;
    return (int)sock;
}

/* Name / info helpers: return static placeholders until implemented */
char *osmo_sock_get_name(const void *ctx, int fd) { (void)fd; (void)ctx; return "frsock"; }
const char *osmo_sock_get_name2(int fd) { (void)fd; return "frsock"; }
char *osmo_sock_get_name2_c(const void *ctx, int fd) { (void)fd; (void)ctx; return "frsock"; }
int osmo_sock_get_name_buf(char *str, size_t str_len, int fd) { (void)fd; if (str_len) { strncpy(str, "frsock", str_len); if (str_len) str[str_len-1]='\0'; } return 0; }
int osmo_sock_get_ip_and_port(int fd, char *ip, size_t ip_len, char *port, size_t port_len, bool local)
{ (void)fd; (void)local; if (ip && ip_len) { strncpy(ip, "0.0.0.0", ip_len); ip[ip_len-1]='\0'; } if (port && port_len) { strncpy(port, "0", port_len); port[port_len-1]='\0'; } return 0; }
int osmo_sock_get_local_ip(int fd, char *host, size_t len) { return osmo_sock_get_ip_and_port(fd, host, len, NULL, 0, true); }
int osmo_sock_get_local_ip_port(int fd, char *port, size_t len) { return osmo_sock_get_ip_and_port(fd, NULL, 0, port, len, true); }
int osmo_sock_get_remote_ip(int fd, char *host, size_t len) { return osmo_sock_get_ip_and_port(fd, host, len, NULL, 0, false); }
int osmo_sock_get_remote_ip_port(int fd, char *port, size_t len) { return osmo_sock_get_ip_and_port(fd, NULL, 0, port, len, false); }

/* Unimplemented multi-address & advanced functions (multicast disabled) */
int osmo_sock_init2_multiaddr(uint16_t f, uint16_t t, uint8_t p, const char **lh, size_t lhc, uint16_t lp, const char **rh, size_t rhc, uint16_t rp, unsigned int fl) {
    (void)f;(void)t;(void)p;(void)lh;(void)lhc;(void)lp;(void)rh;(void)rhc;(void)rp;(void)fl; errno=ENOTSUP; return -1; }
int osmo_sock_init2_multiaddr2(uint16_t f, uint16_t t, uint8_t p, const char **lh, size_t lhc, uint16_t lp, const char **rh, size_t rhc, uint16_t rp, unsigned int fl, struct osmo_sock_init2_multiaddr_pars *pars) {
    (void)f;(void)t;(void)p;(void)lh;(void)lhc;(void)lp;(void)rh;(void)rhc;(void)rp;(void)fl;(void)pars; errno=ENOTSUP; return -1; }
int osmo_sock_init_osa(uint16_t t, uint8_t p, const struct osmo_sockaddr *l, const struct osmo_sockaddr *r, unsigned int fl) { (void)t;(void)p;(void)l;(void)r;(void)fl; errno=ENOTSUP; return -1; }
int osmo_sock_init_ofd(struct osmo_fd *ofd, int family, int type, int proto, const char *host, uint16_t port, unsigned int flags) { (void)ofd;(void)family;(void)type;(void)proto;(void)host;(void)port;(void)flags; errno=ENOTSUP; return -1; }
int osmo_sock_init2_ofd(struct osmo_fd *ofd, int family, int type, int proto, const char *lh, uint16_t lp, const char *rh, uint16_t rp, unsigned int flags) { (void)ofd;(void)family;(void)type;(void)proto;(void)lh;(void)lp;(void)rh;(void)rp;(void)flags; errno=ENOTSUP; return -1; }
int osmo_sock_init_osa_ofd(struct osmo_fd *ofd, int type, int proto, const struct osmo_sockaddr *l, const struct osmo_sockaddr *r, unsigned int flags) { (void)ofd;(void)type;(void)proto;(void)l;(void)r;(void)flags; errno=ENOTSUP; return -1; }
int osmo_sock_unix_init(uint16_t type, uint8_t proto, const char *socket_path, unsigned int flags) { (void)type;(void)proto;(void)socket_path;(void)flags; errno=ENOTSUP; return -1; }
int osmo_sock_unix_init_ofd(struct osmo_fd *ofd, uint16_t type, uint8_t proto, const char *socket_path, unsigned int flags) { (void)ofd;(void)type;(void)proto;(void)socket_path;(void)flags; errno=ENOTSUP; return -1; }
int osmo_sock_multiaddr_get_ip_and_port(int fd, int ip_proto, char *ip, size_t *ip_cnt, size_t ip_len, char *port, size_t port_len, bool local) { (void)fd;(void)ip_proto;(void)ip;(void)ip_cnt;(void)ip_len;(void)port;(void)port_len;(void)local; errno=ENOTSUP; return -1; }
int osmo_multiaddr_ip_and_port_snprintf(char *str, size_t str_len, const char *ip, size_t ip_cnt, size_t ip_len, const char *portbuf) { (void)str;(void)str_len;(void)ip;(void)ip_cnt;(void)ip_len;(void)portbuf; errno=ENOTSUP; return -1; }
int osmo_sock_multiaddr_get_name_buf(char *str, size_t str_len, int fd, int sk_proto) { (void)str;(void)str_len;(void)fd;(void)sk_proto; errno=ENOTSUP; return -1; }
int osmo_sock_multiaddr_add_local_addr(int sfd, const char **addrs, size_t addrs_cnt) { (void)sfd;(void)addrs;(void)addrs_cnt; errno=ENOTSUP; return -1; }
int osmo_sock_multiaddr_del_local_addr(int sfd, const char **addrs, size_t addrs_cnt) { (void)sfd;(void)addrs;(void)addrs_cnt; errno=ENOTSUP; return -1; }
#ifdef DISABLE_OSMO_MCAST
int osmo_sock_mcast_loop_set(int fd, bool enable) { (void)fd;(void)enable; errno=ENOTSUP; return -1; }
int osmo_sock_mcast_ttl_set(int fd, uint8_t ttl) { (void)fd;(void)ttl; errno=ENOTSUP; return -1; }
int osmo_sock_mcast_all_set(int fd, bool enable) { (void)fd;(void)enable; errno=ENOTSUP; return -1; }
int osmo_sock_mcast_iface_set(int fd, const char *ifname) { (void)fd;(void)ifname; errno=ENOTSUP; return -1; }
int osmo_sock_mcast_subscribe(int fd, const char *grp_addr) { (void)fd;(void)grp_addr; errno=ENOTSUP; return -1; }
#endif
int osmo_sock_local_ip(char *local_ip, const char *remote_ip) { (void)remote_ip; if (local_ip) strcpy(local_ip, "0.0.0.0"); return 0; }
int osmo_sock_set_dscp(int fd, uint8_t dscp) { (void)fd;(void)dscp; return 0; }
int osmo_sock_set_priority(int fd, int prio) { (void)fd;(void)prio; return 0; }
int osmo_sock_sctp_get_peer_addr_info(int fd, struct sctp_paddrinfo *pinfo, size_t *pinfo_cnt) { (void)fd;(void)pinfo;(void)pinfo_cnt; errno=ENOTSUP; return -1; }

#endif /* OSMO_FREERTOS && !HAVE_SYS_SOCKET_H */
