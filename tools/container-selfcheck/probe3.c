/* probe3.c - real-device syscall self-check (freestanding, x86_64 + aarch64)
 *
 * Answers, on ANY device: which syscalls does the Android app seccomp policy
 * deny to this container, and does the guest's path handling (utimensat,
 * clone, unshare) work?
 *
 * Build:
 *   clang --target=aarch64-linux-android21 -nostdlib -static -O1 -o probe3 probe3.c
 *   clang --target=x86_64-linux-android21  -nostdlib -static -O1 -o probe3 probe3.c
 */
typedef unsigned long u64;
typedef long i64;

#if defined(__x86_64__)
static inline i64 sc6(i64 n, i64 a1, i64 a2, i64 a3, i64 a4, i64 a5, i64 a6)
{
	i64 ret;
	register i64 r10 __asm__("r10") = a4;
	register i64 r8 __asm__("r8") = a5;
	register i64 r9 __asm__("r9") = a6;
	__asm__ __volatile__("syscall" : "=a"(ret)
		: "a"(n), "D"(a1), "S"(a2), "d"(a3), "r"(r10), "r"(r8), "r"(r9)
		: "rcx", "r11", "memory");
	return ret;
}
#define SYS_read 0
#define SYS_write 1
#define SYS_close 3
#define SYS_fstat 5
#define SYS_poll 7
#define SYS_select 23
#define SYS_ioctl 16
#define SYS_socket 41
#define SYS_connect 42
#define SYS_sendto 44
#define SYS_recvfrom 45
#define SYS_bind 49
#define SYS_clone 56
#define SYS_uname 63
#define SYS_fcntl 72
#define SYS_statfs 137
#define SYS_epoll_wait 232
#define SYS_exit 60
#define SYS_wait4 61
#define SYS_openat 257
#define SYS_pselect6 270
#define SYS_ppoll 271
#define SYS_epoll_create1 291
#define SYS_utimensat 280
#define SYS_unshare 272
#define SYS_chroot 161
#define SYS_getrandom 318
#elif defined(__aarch64__)
static inline i64 sc6(i64 n, i64 a1, i64 a2, i64 a3, i64 a4, i64 a5, i64 a6)
{
	register i64 x8 __asm__("x8") = n;
	register i64 x0 __asm__("x0") = a1;
	register i64 x1 __asm__("x1") = a2;
	register i64 x2 __asm__("x2") = a3;
	register i64 x3 __asm__("x3") = a4;
	register i64 x4 __asm__("x4") = a5;
	register i64 x5 __asm__("x5") = a6;
	__asm__ __volatile__("svc #0" : "+r"(x0)
		: "r"(x8), "r"(x1), "r"(x2), "r"(x3), "r"(x4), "r"(x5) : "memory");
	return x0;
}
#define SYS_read 63
#define SYS_write 64
#define SYS_close 57
#define SYS_fstat 80
/* NOTE: arm64 (asm-generic table) has NO poll/select/epoll_wait syscalls at
 * all - libc implements them on top of ppoll/pselect6/epoll_pwait.  That is
 * exactly why the x86_64-only "poll blocked" failure cannot happen here. */
#define SYS_poll (-1)
#define SYS_select (-1)
#define SYS_ioctl 29
#define SYS_epoll_wait (-1)
#define SYS_exit 93
#define SYS_wait4 260
#define SYS_socket 198
#define SYS_connect 203
#define SYS_sendto 206
#define SYS_recvfrom 207
#define SYS_bind 200
#define SYS_clone 220
#define SYS_uname 160
#define SYS_fcntl 25
#define SYS_statfs 43
#define SYS_openat 56
#define SYS_pselect6 72
#define SYS_ppoll 73
#define SYS_epoll_create1 20
#define SYS_utimensat 88
#define SYS_unshare 97
#define SYS_chroot 51
#define SYS_getrandom 278
#endif

static i64 sc0(i64 n) { return sc6(n, 0, 0, 0, 0, 0, 0); }
static i64 sc1(i64 n, i64 a) { return sc6(n, a, 0, 0, 0, 0, 0); }
static i64 sc2(i64 n, i64 a, i64 b) { return sc6(n, a, b, 0, 0, 0, 0); }
static i64 sc3(i64 n, i64 a, i64 b, i64 c) { return sc6(n, a, b, c, 0, 0, 0); }
static i64 sc4(i64 n, i64 a, i64 b, i64 c, i64 d) { return sc6(n, a, b, c, d, 0, 0); }

static void put(const char *s)
{
	i64 n = 0;
	while (s[n]) n++;
	sc3(SYS_write, 1, (i64)s, n);
}

static void putnum(i64 v)
{
	char b[24];
	int i = 24, neg = v < 0;
	unsigned long u = neg ? (unsigned long)(-v) : (unsigned long)v;
	if (v == 0) { put("0"); return; }
	b[--i] = 0;
	while (u) { b[--i] = '0' + (u % 10); u /= 10; }
	if (neg) b[--i] = '-';
	put(&b[i]);
}

/* print a line, and for negative returns append a verdict */
static void show(const char *name, i64 ret)
{
	put(name); put(" = "); putnum(ret);
	if (ret == -38) put("   <-- ENOSYS (blocked by policy)");
	else if (ret == -1) put("   <-- EPERM");
	else if (ret == -9) put("   <-- EBADF");
	else if (ret == -13) put("   <-- EACCES");
	put("\n");
}

struct sockaddr_in { unsigned short f; unsigned short p; unsigned int a; unsigned char pad[8]; };
struct pollfd { int fd; short events; short revents; };
struct timespec { long s; long n; };
struct timeval { long s; long us; };

void prog_main(void);

#if defined(__x86_64__)
__asm__(
	".globl _start\n"
	"_start:\n"
	"  andq $-16, %rsp\n"
	"  call prog_main\n"
	"  movl $60, %eax\n"
	"  xorl %edi, %edi\n"
	"  syscall\n"
);
#else
__asm__(
	".globl _start\n"
	"_start:\n"
	"  bl prog_main\n"
	"  mov x0, #0\n"
	"  mov x8, #93\n"
	"  svc #0\n"
);
#endif

void prog_main(void)
{
	i64 r, fd, sfd, dfd, ofd;
	struct pollfd pfd;
	struct timespec ts;
	struct timeval tv;
	struct sockaddr_in ns;
	long ubuf[64];

	put("=== probe3 (real device syscall self-check) ===\n");

	/* --- wait primitives: the ones Android denies to app processes --- */
	fd = sc3(SYS_socket, 2, 2, 0);		/* AF_INET, SOCK_DGRAM */
	show("socket(UDP)", fd);
	if (fd >= 0) {
		pfd.fd = (int)fd; pfd.events = 1; pfd.revents = 0;
		ts.s = 0; ts.n = 200000000L;	/* 200ms */
#if defined(__x86_64__)
		show("poll(fd,POLLIN,200ms)", sc3(SYS_poll, (i64)&pfd, 1, 200));
#else
		put("poll(...)              = N/A on arm64 (syscall does not exist)\n");
#endif
		pfd.revents = 0;
		show("ppoll(fd,POLLIN,200ms)", sc6(SYS_ppoll, (i64)&pfd, 1, (i64)&ts, 0, 0, 0));
		tv.s = 0; tv.us = 0;
#if defined(__x86_64__)
		show("select(0,NULL,NULL,NULL,{0,0})", sc6(SYS_select, 0, 0, 0, 0, (i64)&tv, 0));
#else
		put("select(...)            = N/A on arm64 (syscall does not exist)\n");
#endif
		show("pselect6(0,...,{0})", sc6(SYS_pselect6, 0, 0, 0, 0, (i64)&ts, 0));
		r = sc1(SYS_epoll_create1, 0);
		show("epoll_create1(0)", r);
#if defined(__x86_64__)
		if (r >= 0)
			show("epoll_wait(epfd,1,0)", sc4(SYS_epoll_wait, r, (i64)ubuf, 1, 0));
#else
		if (r >= 0) {
			/* arm64 only has epoll_pwait (22) */
			show("epoll_pwait(epfd,1,0,NULL)", sc6(22, r, (i64)ubuf, 1, 0, 0, 0));
		}
#endif
		show("fcntl(F_GETFL)", sc4(SYS_fcntl, fd, 3, 0, 0));
		r = sc4(SYS_fcntl, fd, 3, 0, 0);
		show("fcntl(F_SETFL,|NONBLOCK)", sc4(SYS_fcntl, fd, 4, r | 0x800, 0));
		show("fcntl(F_SETFL,&~NONBLOCK)", sc4(SYS_fcntl, fd, 4, r & ~0x800, 0));
		{
			int one = 1;
			show("ioctl(FIONBIO)", sc3(SYS_ioctl, fd, 0x5421, (i64)&one));
		}
		sc1(SYS_close, fd);
	}

	/* --- TCP + DNS-relevant --- */
	sfd = sc3(SYS_socket, 2, 1, 0);
	show("socket(TCP)", sfd);
	ns.f = 2; ns.p = 0x3500; ns.a = 0x08080808;	/* 8.8.8.8:53 */
	if (sfd >= 0) {
		show("bind(UDP 0.0.0.0:0)", sc3(SYS_bind, sfd, (i64)&ns, 16));
		sc1(SYS_close, sfd);
	}

	/* --- file/path handling used by apk's installer --- */
	show("openat(create /root/utest)", fd = sc4(SYS_openat, -100, (i64)"/root/utest",
		0x40 | 1 | 0x200, 0644));
	if (fd >= 0) sc1(SYS_close, fd);
	show("utimensat(AT_FDCWD, abs)", sc4(SYS_utimensat, -100, (i64)"/root/utest", 0, 0));
	show("utimensat(AT_FDCWD, rel)", sc4(SYS_utimensat, -100, (i64)"utest", 0, 0));
	dfd = sc4(SYS_openat, -100, (i64)"/root", 0x10000, 0);
	show("openat(/root, O_DIRECTORY)", dfd);
	if (dfd >= 0) {
		show("utimensat(dirfd, rel) [apk style]", sc4(SYS_utimensat, dfd, (i64)"utest", 0, 0));
		show("utimensat(dirfd, rel, NOFOLLOW)", sc4(SYS_utimensat, dfd, (i64)"utest", 0, 0x100));
		ofd = sc4(SYS_openat, dfd, (i64)"utest", 0x200000, 0);
		show("openat(dirfd, rel, O_PATH)", ofd);
		if (ofd >= 0) {
			show("utimensat(fd, \"\", AT_EMPTY_PATH)", sc4(SYS_utimensat, ofd, (i64)"", 0, 0x1000));
			sc1(SYS_close, ofd);
		}
		sc1(SYS_close, dfd);
	}
	show("fstat(1)", sc2(SYS_fstat, 1, (i64)ubuf));
	show("statfs(\"/\")", sc2(SYS_statfs, (i64)"/", (i64)ubuf));

	/* --- process creation: what apk's trigger scripts and shells need --- */
	{
		i64 pid = sc6(SYS_clone, 17 /*SIGCHLD*/, 0, 0, 0, 0, 0);
		if (pid == 0) {			/* child: leave immediately */
			sc1(SYS_exit, 0);
			for (;;) {}
		}
		show("clone(SIGCHLD) [=fork]", pid);
		if (pid > 0) {
			i64 st = 0;
			/* wait4(pid, &st, 0, 0) = 61 on x86_64 / 260 on aarch64 */
			sc4(SYS_wait4, pid, (i64)&st, 0, 0);
		}
	}
	show("unshare(CLONE_NEWNS)", sc1(SYS_unshare, 0x00020000));
	show("getrandom(8)", sc3(SYS_getrandom, (i64)ubuf, 8, 1));
	show("uname", sc1(SYS_uname, (i64)ubuf));

	put("=== probe3 done ===\n");

	/* last: chroot is irreversible enough to keep at the very end */
	show("chroot(\"/\")", sc1(SYS_chroot, (i64)"/"));
	sc1(SYS_exit, 0);
	for (;;) {}
}
