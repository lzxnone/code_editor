/* probe8.c - fork 路径各变体的 errno 定位（静态、裸 syscall）
 * Build: clang --target=x86_64-linux-android24 -nostdlib -static -O1 -o probe8 probe8.c
 */
typedef long i64;
typedef unsigned long u64;

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
#define SYS_exit 60
#define SYS_wait4 61
#define SYS_clone 56
#define SYS_fork 57
#define SYS_vfork 58
#define SYS_clone3 435
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
#define SYS_exit 93
#define SYS_wait4 260
#define SYS_clone 220
#define SYS_clone3 435
#define SYS_fork 0 /* 不存在 */
#endif

static i64 sc1(i64 n, i64 a) { return sc6(n, a, 0, 0, 0, 0, 0); }
static i64 sc2(i64 n, i64 a, i64 b) { return sc6(n, a, b, 0, 0, 0, 0); }
static i64 sc4(i64 n, i64 a, i64 b, i64 c, i64 d) { return sc6(n, a, b, c, d, 0, 0); }
static i64 sc0(i64 n) { return sc6(n, 0, 0, 0, 0, 0, 0); }

static i64 sc3w(const char *s, i64 n) { return sc6(SYS_write, 1, (i64)s, n, 0, 0, 0); }
static void put(const char *s) { i64 n = 0; while (s[n]) n++; sc3w(s, n); }
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
	put("  "); put(n); put(" = "); putnum(r);
	if (r == -38) put("   [ENOSYS 被平台拒绝]");
	else if (r == -1) put("   [EPERM]");
	else if (r > 0) put("   [成功]");
	put("\n");
}

void prog_main(void);
#if defined(__x86_64__)
__asm__(".globl _start\n_start:\n  andq $-16, %rsp\n  call prog_main\n"
	"  movl $60, %eax\n  xorl %edi, %edi\n  syscall\n");
#else
__asm__(".globl _start\n_start:\n  bl prog_main\n  mov x0, #0\n  mov x8, #93\n  svc #0\n");
#endif

#define SIGCHLD_ 17
#define CLONE_VM_ 0x00000100
#define CLONE_VFORK_ 0x00004000

struct clone_args {
	u64 flags, pidfd, child_tid, parent_tid, exit_signal,
	    stack, stack_size, tls, set_tid, set_tid_size, cgroup;
};

void prog_main(void)
{
	i64 r;
	struct clone_args ca;

	put("=== probe8: fork 路径变体（静态探针，量 proot 改写后的裸行为）===\n");

	/* 1. classic clone(SIGCHLD) —— 最标准的 fork 实现 */
	r = sc6(SYS_clone, SIGCHLD_, 0, 0, 0, 0, 0);
	if (r == 0) { sc1(SYS_exit, 0); for (;;) {} }
	show("clone(SIGCHLD)", r);
	if (r > 0) sc4(SYS_wait4, r, 0, 0, 0);

	/* 2. vfork 语义：CLONE_VM|CLONE_VFORK */
	r = sc6(SYS_clone, CLONE_VM_ | CLONE_VFORK_ | SIGCHLD_, 0, 0, 0, 0, 0);
	if (r == 0) { sc1(SYS_exit, 0); for (;;) {} }
	show("clone(VM|VFORK|SIGCHLD)", r);
	if (r > 0) sc4(SYS_wait4, r, 0, 0, 0);

	/* 3. clone3(flags=SIGCHLD) */
	{
		int i; char *p = (char *)&ca;
		for (i = 0; i < (int)sizeof(ca); i++) p[i] = 0;
	}
	ca.flags = SIGCHLD_;
	r = sc2(SYS_clone3, (i64)&ca, sizeof(ca));
	if (r == 0) { sc1(SYS_exit, 0); for (;;) {} }
	show("clone3(flags=SIGCHLD)", r);
	if (r > 0) sc4(SYS_wait4, r, 0, 0, 0);

	/* 4. clone3(flags=CLONE_VM|CLONE_VFORK|SIGCHLD) */
	ca.flags = CLONE_VM_ | CLONE_VFORK_ | SIGCHLD_;
	r = sc2(SYS_clone3, (i64)&ca, sizeof(ca));
	if (r == 0) { sc1(SYS_exit, 0); for (;;) {} }
	show("clone3(VM|VFORK|SIGCHLD)", r);
	if (r > 0) sc4(SYS_wait4, r, 0, 0, 0);

#if defined(__x86_64__)
	/* 5. 传统 fork / vfork 系统调用号 */
	r = sc0(SYS_fork);
	if (r == 0) { sc1(SYS_exit, 0); for (;;) {} }
	show("fork(57)", r);
	if (r > 0) sc4(SYS_wait4, r, 0, 0, 0);

	r = sc0(SYS_vfork);
	if (r == 0) { sc1(SYS_exit, 0); for (;;) {} }
	show("vfork(58)", r);
	if (r > 0) sc4(SYS_wait4, r, 0, 0, 0);
#endif

	put("=== done ===\n");
	sc1(SYS_exit, 0);
	for (;;) {}
}
