/* probe5.c - is the old "empty path triggers PRoot EINVAL" workaround still needed?
 * Tests newfstatat(fd, "", buf, AT_EMPTY_PATH) and fstat(fd) under PRoot.
 * Build: clang --target=aarch64-linux-android21 -nostdlib -static -O1 -o probe5 probe5.c
 */
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
#define SYS_write 1
#define SYS_close 3
#define SYS_fstat 5
#define SYS_openat 257
#define SYS_newfstatat 262
#define SYS_exit 60
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
#define SYS_write 64
#define SYS_close 57
#define SYS_fstat 80
#define SYS_openat 56
#define SYS_newfstatat 79
#define SYS_exit 93
#endif

static i64 sc1(i64 n, i64 a) { return sc6(n, a, 0, 0, 0, 0, 0); }
static i64 sc2(i64 n, i64 a, i64 b) { return sc6(n, a, b, 0, 0, 0, 0); }
static i64 sc3(i64 n, i64 a, i64 b, i64 c) { return sc6(n, a, b, c, 0, 0, 0); }
static i64 sc4(i64 n, i64 a, i64 b, i64 c, i64 d) { return sc6(n, a, b, c, d, 0, 0); }

static void put(const char *s) { i64 n = 0; while (s[n]) n++; sc3(SYS_write, 1, (i64)s, n); }
static void putnum(i64 v)
{
	char b[24]; int i = 24, neg = v < 0;
	unsigned long u = neg ? (unsigned long)(-v) : (unsigned long)v;
	if (v == 0) { put("0"); return; }
	b[--i] = 0;
	while (u) { b[--i] = '0' + (u % 10); u /= 10; }
	if (neg) b[--i] = '-';
	put(&b[i]);
}
static void show(const char *n, i64 r)
{
	put(n); put(" = "); putnum(r);
	if (r == -22) put("  [EINVAL]");
	else if (r == -2) put("  [ENOENT]");
	else if (r == -9) put("  [EBADF]");
	put("\n");
}

void prog_main(void);
#if defined(__x86_64__)
__asm__(".globl _start\n_start:\n  andq $-16, %rsp\n  call prog_main\n"
	"  movl $60, %eax\n  xorl %edi, %edi\n  syscall\n");
#else
__asm__(".globl _start\n_start:\n  bl prog_main\n  mov x0, #0\n  mov x8, #93\n  svc #0\n");
#endif

void prog_main(void)
{
	i64 fd;
	long st[64];
	put("=== probe5: empty-path stat workaround check ===\n");
	fd = sc4(SYS_openat, -100, (i64)"/etc/profile", 0, 0);
	show("openat(/etc/profile)", fd);
	if (fd >= 0) {
		show("fstat(fd)", sc2(SYS_fstat, fd, (i64)st));
		show("newfstatat(fd, \"\", st, 0)              [empty path]",
		     sc4(SYS_newfstatat, fd, (i64)"", (i64)st, 0));
		show("newfstatat(fd, \"\", st, AT_EMPTY_PATH)  [0x1000]",
		     sc4(SYS_newfstatat, fd, (i64)"", (i64)st, 0x1000));
		sc1(SYS_close, fd);
	}
	/* also a directory fd, which is what some tools use */
	fd = sc4(SYS_openat, -100, (i64)"/etc", 0, 0);
	show("openat(/etc, RDONLY)", fd);
	if (fd >= 0) {
		show("newfstatat(dfd, \"\", st, AT_EMPTY_PATH)",
		     sc4(SYS_newfstatat, fd, (i64)"", (i64)st, 0x1000));
		sc1(SYS_close, fd);
	}
	put("=== probe5 done ===\n");
	sc1(SYS_exit, 0);
	for (;;) {}
}
