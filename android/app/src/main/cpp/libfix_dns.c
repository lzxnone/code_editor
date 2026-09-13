/*
 * libfix_dns.c - getaddrinfo() for the x86_64 emulator case.  x86_64 ONLY.
 *
 * WHY (measured, x86_64 emulator only)
 * ------------------------------------
 * Android's app seccomp policy answers the legacy poll(2) syscall with ENOSYS.
 * x86_64 is one of the architectures where that syscall still exists, musl's
 * poll() uses it whenever it does (musl: `#ifdef SYS_poll`), and musl's stub
 * resolver calls poll() from *inside libc* - where LD_PRELOAD cannot reach it.
 * The resolver therefore times out, getaddrinfo() returns EAI_AGAIN, apk's
 * libfetch maps that to FETCH_TEMP and prints
 *
 *     temporary error (try again later)
 *
 * arm64 (asm-generic syscall table) has no poll/select at all: libc uses
 * ppoll/pselect6, nothing can be denied, and the native resolver works.  So
 * this file is compiled for x86_64 only and arm64 keeps pristine libc.
 *
 * getaddrinfo() itself *is* interposable (it is called through the PLT), so
 * this file answers it from /etc/hosts and, failing that, with its own A/AAAA
 * query that waits with ppoll().  Deliberately lenient about the reply's
 * source address: Android may answer port 53 from a proxy, and accepting that
 * is exactly what makes busybox's nslookup and c-ares work here.
 *
 * Freestanding: raw syscalls, memory from mmap, no libc dependency.
 */

#if defined(__x86_64__)

typedef unsigned long size_t;
typedef long ssize_t;
typedef unsigned short u16;
typedef unsigned int u32;

static inline long sc6(long n, long a1, long a2, long a3, long a4, long a5, long a6)
{
	long ret;
	register long r10 __asm__("r10") = a4;
	register long r8 __asm__("r8") = a5;
	register long r9 __asm__("r9") = a6;
	__asm__ __volatile__("syscall" : "=a"(ret)
		: "a"(n), "D"(a1), "S"(a2), "d"(a3), "r"(r10), "r"(r8), "r"(r9)
		: "rcx", "r11", "memory");
	return ret;
}

#define SYS_read 0
#define SYS_close 3
#define SYS_mmap 9
#define SYS_munmap 11
#define SYS_socket 41
#define SYS_sendto 44
#define SYS_recvfrom 45
#define SYS_openat 257
#define SYS_ppoll 271

#define AF_UNSPEC 0
#define AF_INET 2
#define AF_INET6 10
#define SOCK_STREAM 1
#define SOCK_DGRAM 2

#define AI_PASSIVE 0x0001
#define AI_NUMERICHOST 0x0004

#define EAI_NONAME (-2)
#define EAI_SERVICE (-8)
#define EAI_MEMORY (-10)
#define EAI_FAIL (-11)

#define AT_FDCWD (-100)
#define O_RDONLY 0
#define PROT_READ 1
#define PROT_WRITE 2
#define MAP_PRIVATE 2
#define MAP_ANONYMOUS 0x20
#define POLLIN 0x001

struct pollfd { int fd; short events; short revents; };
struct timespec { long tv_sec; long tv_nsec; };
struct in_addr { u32 s_addr; };
struct in6_addr { unsigned char s6_addr[16]; };
struct sockaddr { u16 sa_family; char sa_data[14]; };
struct sockaddr_in { u16 sin_family; u16 sin_port; struct in_addr sin_addr; char sin_zero[8]; };
struct sockaddr_in6 {
	u16 sin6_family;
	u16 sin6_port;
	u32 sin6_flowinfo;
	struct in6_addr sin6_addr;
	u32 sin6_scope_id;
};

/* musl/glibc-compatible layout */
struct addrinfo {
	int ai_flags;
	int ai_family;
	int ai_socktype;
	int ai_protocol;
	unsigned int ai_addrlen;
	struct sockaddr *ai_addr;
	char *ai_canonname;
	struct addrinfo *ai_next;
};

/* --------------------------------------------------------------- primitives */

static void *my_memset(void *d, int c, size_t n)
{
	unsigned char *p = d;
	while (n--) *p++ = (unsigned char)c;
	return d;
}

static void *my_memcpy(void *d, const void *s, size_t n)
{
	unsigned char *a = d;
	const unsigned char *b = s;
	while (n--) *a++ = *b++;
	return d;
}

static int lower(int c) { return (c >= 'A' && c <= 'Z') ? c + 32 : c; }

static int name_eq(const char *a, const char *b)
{
	while (*a && *b) {
		if (lower(*a) != lower(*b)) return 0;
		a++;
		b++;
	}
	return *a == *b;
}

static void *xalloc(size_t n)
{
	long r = sc6(SYS_mmap, 0, (long)n, PROT_READ | PROT_WRITE,
		     MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
	if (r < 0 && r > -4096) return 0;
	return (void *)r;
}

static void xfree(void *p, size_t n)
{
	if (p) sc6(SYS_munmap, (long)p, (long)n, 0, 0, 0, 0);
}

static int read_file(const char *path, char *buf, size_t max)
{
	long fd = sc6(SYS_openat, AT_FDCWD, (long)path, O_RDONLY, 0, 0, 0);
	size_t total = 0;
	if (fd < 0) return -1;
	for (;;) {
		long r = sc6(SYS_read, fd, (long)(buf + total), (long)(max - 1 - total), 0, 0, 0);
		if (r <= 0) break;
		total += (size_t)r;
		if (total >= max - 1) break;
	}
	sc6(SYS_close, fd, 0, 0, 0, 0, 0);
	buf[total] = 0;
	return (int)total;
}

/* next whitespace-delimited token of *p; advances *p; returns its length */
static int next_token(const char **p, char *out, int max)
{
	const char *s = *p;
	int n = 0;
	while (*s == ' ' || *s == '\t') s++;
	while (*s && *s != ' ' && *s != '\t' && *s != '\n' && *s != '#') {
		if (n < max - 1) out[n++] = *s;
		s++;
	}
	out[n] = 0;
	*p = s;
	return n;
}

/* parse a dotted-quad IPv4 address; returns 1 on success, network order out */
static int parse_ipv4(const char *s, u32 *out)
{
	u32 v = 0;
	int k;
	const char *q = s;
	for (k = 0; k < 4; k++) {
		int d = 0, nd = 0;
		while (*q >= '0' && *q <= '9' && nd < 4) { d = d * 10 + (*q - '0'); q++; nd++; }
		if (nd == 0 || d > 255) return 0;
		v = (v << 8) | (u32)d;
		if (k < 3) {
			if (*q != '.') return 0;
			q++;
		}
	}
	if (*q) return 0;
	*out = v;
	return 1;
}

/* ------------------------------------------------------------- /etc/hosts */

static int hosts_lookup(const char *name, u32 *v4, int v4max)
{
	static char buf[16384];
	int len = read_file("/etc/hosts", buf, sizeof buf);
	int n4 = 0, i = 0;

	if (len <= 0) return -1;
	while (i < len) {
		char line[512], addr[128], nm[256];
		const char *p;
		int li = 0;
		u32 a4;

		while (i < len && buf[i] != '\n') {
			if (li < (int)sizeof(line) - 1) line[li++] = buf[i];
			i++;
		}
		i++;
		line[li] = 0;

		p = line;
		if (next_token(&p, addr, sizeof addr) == 0) continue;
		if (!parse_ipv4(addr, &a4)) continue;	/* IPv6 entries are ignored */
		for (;;) {
			if (next_token(&p, nm, sizeof nm) == 0) break;
			if (name_eq(nm, name) && n4 < v4max) v4[n4++] = a4;
		}
	}
	return n4 ? n4 : -1;
}

/* ------------------------------------------------------- /etc/resolv.conf */

static int resolv_nameservers(u32 *ns, int max)
{
	static char buf[4096];
	int len = read_file("/etc/resolv.conf", buf, sizeof buf);
	int n = 0, i = 0;
	static const char kw[] = "nameserver";

	if (len <= 0) return 0;
	while (i < len && n < max) {
		char line[256], ip[64];
		const char *p;
		int li = 0, k;
		u32 a4;

		while (i < len && buf[i] != '\n') {
			if (li < (int)sizeof(line) - 1) line[li++] = buf[i];
			i++;
		}
		i++;
		line[li] = 0;

		for (k = 0; k < 10; k++)
			if (line[k] != kw[k]) break;
		if (k != 10) continue;
		if (line[10] != ' ' && line[10] != '\t') continue;

		p = line + 10;
		if (next_token(&p, ip, sizeof ip) == 0) continue;
		if (parse_ipv4(ip, &a4)) ns[n++] = a4;
	}
	return n;
}

/* ---------------------------------------------------------------- DNS wire */

#define QID_HI 0x4c
#define QID_LO 0x37

static int build_query(unsigned char *q, int max, const char *name, int qtype)
{
	int n = 12;

	my_memset(q, 0, 12);
	q[0] = QID_HI;
	q[1] = QID_LO;
	q[2] = 0x01;			/* RD */
	q[5] = 1;			/* QDCOUNT = 1 */

	while (*name) {
		const char *dot = name;
		int l;
		while (*dot && *dot != '.') dot++;
		l = (int)(dot - name);
		if (l <= 0 || l > 63 || n + l + 1 > max - 4) return -1;
		q[n++] = (unsigned char)l;
		my_memcpy(q + n, name, (size_t)l);
		n += l;
		name = (*dot == '.') ? dot + 1 : dot;
	}
	q[n++] = 0;
	q[n++] = (unsigned char)(qtype >> 8);
	q[n++] = (unsigned char)(qtype & 0xff);
	q[n++] = 0;
	q[n++] = 1;			/* IN */
	return n;
}

static int skip_dns_name(const unsigned char *m, int len, int off)
{
	while (off < len) {
		unsigned char c = m[off];
		if (c == 0) return off + 1;
		if ((c & 0xc0) == 0xc0) return off + 2;
		off += 1 + c;
	}
	return -1;
}

static void parse_answers(const unsigned char *m, int len,
			  u32 *out4, int *n4, unsigned char (*out6)[16], int *n6)
{
	int i = 12;
	int qd = (m[4] << 8) | m[5];
	int an = (m[6] << 8) | m[7];

	while (qd-- > 0) {
		i = skip_dns_name(m, len, i);
		if (i < 0 || i + 4 > len) return;
		i += 4;
	}
	while (an-- > 0) {
		int type, rdlen;
		i = skip_dns_name(m, len, i);
		if (i < 0 || i + 10 > len) return;
		type = (m[i] << 8) | m[i + 1];
		rdlen = (m[i + 8] << 8) | m[i + 9];
		i += 10;
		if (i + rdlen > len) return;
		if (type == 1 && rdlen == 4 && *n4 < 16) {
			my_memcpy(&out4[*n4], m + i, 4);
			(*n4)++;
		} else if (type == 28 && rdlen == 16 && *n6 < 16) {
			my_memcpy(out6[*n6], m + i, 16);
			(*n6)++;
		}
		i += rdlen;
	}
}

/*
 * Ask every configured nameserver at once (as musl does) and take the first
 * reply that carries our query id.  The reply's source address is *not*
 * checked on purpose.
 */
static int dns_query(const char *name, int qtype, int timeout_ms,
		     u32 *out4, int *n4, unsigned char (*out6)[16], int *n6)
{
	unsigned char q[512], rbuf[2048];
	struct sockaddr_in to;
	struct pollfd pfd;
	struct timespec ts;
	u32 ns[3];
	int nns, i, qlen;
	long fd, r;

	qlen = build_query(q, (int)sizeof q, name, qtype);
	if (qlen < 0) return -1;

	nns = resolv_nameservers(ns, 3);
	if (nns == 0) {
		ns[0] = 0x08080808;		/* 8.8.8.8 */
		ns[1] = 0x01010101;		/* 1.1.1.1 */
		nns = 2;
	}

	fd = sc6(SYS_socket, AF_INET, SOCK_DGRAM, 0, 0, 0, 0);
	if (fd < 0) return -1;

	my_memset(&to, 0, sizeof to);
	to.sin_family = AF_INET;
	to.sin_port = 0x3500;			/* port 53, network order */
	for (i = 0; i < nns; i++) {
		to.sin_addr.s_addr = ns[i];	/* already network order */
		sc6(SYS_sendto, fd, (long)q, qlen, 0, (long)&to, sizeof to);
	}

	pfd.fd = (int)fd;
	pfd.events = POLLIN;
	pfd.revents = 0;
	ts.tv_sec = timeout_ms / 1000;
	ts.tv_nsec = (long)(timeout_ms % 1000) * 1000000L;

	r = sc6(SYS_ppoll, (long)&pfd, 1, (long)&ts, 0, 0, 0);
	if (r > 0) {
		r = sc6(SYS_recvfrom, fd, (long)rbuf, (long)sizeof rbuf, 0, 0, 0);
		if (r >= 12 && (rbuf[2] & 0x80) && rbuf[0] == QID_HI && rbuf[1] == QID_LO)
			parse_answers(rbuf, (int)r, out4, n4, out6, n6);
	}
	sc6(SYS_close, fd, 0, 0, 0, 0, 0);
	return (*n4 || *n6) ? 0 : -1;
}

/* ------------------------------------------------------------ service/port */

static unsigned short service_port(const char *svc, int *ok)
{
	static const struct { const char *n; unsigned short p; } tab[] = {
		{ "http", 80 }, { "https", 443 }, { "ftp", 21 }, { "ssh", 22 },
		{ "smtp", 25 }, { "domain", 53 }, { "pop3", 110 }, { "imap", 143 },
		{ "ntp", 123 }, { "git", 9418 },
	};
	unsigned short port;
	unsigned char *b;
	unsigned long v = 0;
	const char *p = svc;
	int i;

	if (!svc || !*svc) { *ok = 1; return 0; }
	if (*p >= '0' && *p <= '9') {
		while (*p >= '0' && *p <= '9') { v = v * 10 + (unsigned long)(*p - '0'); p++; }
		if (*p || v > 65535) { *ok = 0; return 0; }
		port = (unsigned short)v;
	} else {
		for (i = 0; i < (int)(sizeof tab / sizeof tab[0]); i++)
			if (name_eq(tab[i].n, svc)) break;
		if (i == (int)(sizeof tab / sizeof tab[0])) { *ok = 0; return 0; }
		port = tab[i].p;
	}
	b = (unsigned char *)&port;
	*ok = 1;
	return (unsigned short)((b[0] << 8) | b[1]);	/* to network order */
}

static struct addrinfo *mk_ai(int family, const unsigned char *addr,
			      unsigned short port_be, int socktype, int protocol)
{
	size_t alen = (family == AF_INET6) ? sizeof(struct sockaddr_in6)
					   : sizeof(struct sockaddr_in);
	size_t sz = sizeof(struct addrinfo) + alen;
	struct addrinfo *ai = xalloc(sz);

	if (!ai) return 0;
	my_memset(ai, 0, sz);
	ai->ai_family = family;
	ai->ai_socktype = socktype ? socktype : SOCK_STREAM;
	ai->ai_protocol = protocol;
	ai->ai_addrlen = (unsigned int)alen;
	ai->ai_addr = (struct sockaddr *)(ai + 1);
	if (family == AF_INET6) {
		struct sockaddr_in6 *s = (struct sockaddr_in6 *)ai->ai_addr;
		s->sin6_family = AF_INET6;
		s->sin6_port = port_be;
		my_memcpy(s->sin6_addr.s6_addr, addr, 16);
	} else {
		struct sockaddr_in *s = (struct sockaddr_in *)ai->ai_addr;
		s->sin_family = AF_INET;
		s->sin_port = port_be;
		my_memcpy(&s->sin_addr, addr, 4);
	}
	return ai;
}

/* ------------------------------------------------------------ entry points */

__attribute__((visibility("default")))
int getaddrinfo(const char *node, const char *service,
		const struct addrinfo *hints, struct addrinfo **res)
{
	int family = AF_UNSPEC, socktype = 0, protocol = 0, flags = 0;
	unsigned short port_be;
	int ok = 0, i;
	u32 v4[16];
	int n4 = 0;
	unsigned char v6[16][16];
	int n6 = 0;
	struct addrinfo *head = 0, *tail = 0;

	if (hints) {
		family = hints->ai_family;
		socktype = hints->ai_socktype;
		protocol = hints->ai_protocol;
		flags = hints->ai_flags;
	}
	if (!res) return EAI_FAIL;
	*res = 0;

	port_be = service_port(service, &ok);
	if (!ok) return EAI_SERVICE;

	/* no name: wildcard (AI_PASSIVE) or loopback */
	if (!node || !*node) {
		unsigned char any4[4] = { 0, 0, 0, 0 };
		unsigned char lo4[4] = { 127, 0, 0, 1 };
		const unsigned char *a = (flags & AI_PASSIVE) ? any4 : lo4;
		if (family == AF_INET6) {
			unsigned char any6[16];
			my_memset(any6, 0, 16);
			if (!(flags & AI_PASSIVE)) any6[15] = 1;
			head = mk_ai(AF_INET6, any6, port_be, socktype, protocol);
		} else {
			head = mk_ai(AF_INET, a, port_be, socktype, protocol);
		}
		if (!head) return EAI_MEMORY;
		*res = head;
		return 0;
	}

	/* numeric IPv4 literal first */
	{
		u32 a4;
		if (parse_ipv4(node, &a4)) {
			unsigned char b[4];
			if (family == AF_INET6) return EAI_NONAME;
			b[0] = (unsigned char)(a4 & 0xff);
			b[1] = (unsigned char)((a4 >> 8) & 0xff);
			b[2] = (unsigned char)((a4 >> 16) & 0xff);
			b[3] = (unsigned char)((a4 >> 24) & 0xff);
			head = mk_ai(AF_INET, b, port_be, socktype, protocol);
			if (!head) return EAI_MEMORY;
			*res = head;
			return 0;
		}
		if (flags & AI_NUMERICHOST) return EAI_NONAME;
	}

	if (hosts_lookup(node, v4, 16) < 0) {
		if (family == AF_UNSPEC || family == AF_INET)
			dns_query(node, 1, 5000, v4, &n4, v6, &n6);
		if (family == AF_UNSPEC || family == AF_INET6)
			dns_query(node, 28, 5000, v4, &n4, v6, &n6);
	}

	if (family == AF_UNSPEC || family == AF_INET) {
		for (i = 0; i < n4; i++) {
			struct addrinfo *ai = mk_ai(AF_INET, (unsigned char *)&v4[i],
						    port_be, socktype, protocol);
			if (!ai) break;
			if (!head) head = ai; else tail->ai_next = ai;
			tail = ai;
		}
	}
	if (family == AF_UNSPEC || family == AF_INET6) {
		for (i = 0; i < n6; i++) {
			struct addrinfo *ai = mk_ai(AF_INET6, v6[i], port_be, socktype, protocol);
			if (!ai) break;
			if (!head) head = ai; else tail->ai_next = ai;
			tail = ai;
		}
	}

	if (!head) return EAI_NONAME;
	*res = head;
	return 0;
}

__attribute__((visibility("default")))
void freeaddrinfo(struct addrinfo *ai)
{
	while (ai) {
		struct addrinfo *next = ai->ai_next;
		size_t alen = (ai->ai_family == AF_INET6) ? sizeof(struct sockaddr_in6)
							  : sizeof(struct sockaddr_in);
		xfree(ai, sizeof(struct addrinfo) + alen);
		ai = next;
	}
}

#endif /* __x86_64__ */
