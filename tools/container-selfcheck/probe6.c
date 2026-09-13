/* probe6.c - SysV IPC 可用性探针（shmget/semget/msgget + shmat）
 * Build: clang --target=aarch64-linux-android24 -nostdlib -static -O1 -o probe6 probe6.c
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
#define SYS_nanosleep 35
#define SYS_exit 60
#define SYS_shmget 29
#define SYS_shmat 30
#define SYS_shmctl 31
#define SYS_semget 64
#define SYS_msgget 68
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
#define SYS_nanosleep 101
#define SYS_exit 93
#define SYS_shmget 194
#define SYS_shmat 196
#define SYS_shmctl 195
#define SYS_semget 190
#define SYS_msgget 186
#endif

static i64 sc1(i64 n, i64 a) { return sc6(n, a, 0, 0, 0, 0, 0); }
static i64 sc3(i64 n, i64 a, i64 b, i64 c) { return sc6(n, a, b, c, 0, 0, 0); }

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
	put("  "); put(n); put(" = "); putnum(r);
	if (r == -38) put("  [ENOSYS: 被 seccomp 拦]");
	else if (r == -1) put("  [EPERM]");
	else if (r == -13) put("  [EACCES]");
	else if (r >= 0) put("  [OK]");
	put("\n");
}

void prog_main(void);
#if defined(__x86_64__)
__asm__(".globl _start\n_start:\n  andq $-16, %rsp\n  call prog_main\n"
	"  movl $60, %eax\n  xorl %edi, %edi\n  syscall\n");
#else
__asm__(".globl _start\n_start:\n  bl prog_main\n  mov x0, #0\n  mov x8, #93\n  svc #0\n");
#endif

#define IPC_CREAT 01000
#define IPC_RMID 0

#if defined(PROBE6_WRITE) || defined(PROBE6_READ)
/* 跨进程共享内存测试：writer 建段写数据，reader 另起进程附着读取 */
#define TEST_KEY 0x4321
#define MAGIC "SYSVIPC-SHARED!"
void prog_main(void)
{
	i64 shmid, addr;
	const char *tag =
#ifdef PROBE6_WRITE
		"writer";
#else
		"reader";
#endif
	put("=== probe6 "); put(tag); put(" ===\n");
	shmid = sc3(SYS_shmget, TEST_KEY, 4096, IPC_CREAT | 0600);
	show("shmget(key=0x4321)", shmid);
	if (shmid < 0) { sc1(SYS_exit, 1); for (;;) {} }
	addr = sc3(SYS_shmat, shmid, 0, 0);
	show("shmat", addr);
	if (addr < 0) { sc1(SYS_exit, 1); for (;;) {} }

#ifdef PROBE6_WRITE
	{
		char *p = (char *)addr;
		const char *m = MAGIC;
		int i = 0;
		while (m[i]) { p[i] = m[i]; i++; }
		put("  wrote: "); put(MAGIC); put("\n");
		/* 保持在世：真实场景里创建者（如 postmaster）会常驻，别人才能附着 */
		{
			struct ts2 { long s; long ns; } ts = { 60, 0 };
			put("  (keepalive 60s)\n");
			sc6(SYS_nanosleep, (i64)&ts, 0, 0, 0, 0, 0);
		}
	}
#else
	{
		char *p = (char *)addr;
		const char *m = MAGIC;
		int i = 0, ok = 1;
		while (m[i]) { if (p[i] != m[i]) { ok = 0; break; } i++; }
		put("  read : "); 
		for (i = 0; i < 16; i++) put((const char[]){p[i], 0});
		put("\n  cross-process verify = "); put(ok ? "OK" : "MISMATCH"); put("\n");
		show("shmctl(RMID)", sc3(SYS_shmctl, shmid, IPC_RMID, 0));
	}
#endif
	put("=== done ===\n");
	sc1(SYS_exit, 0);
	for (;;) {}
}
#else
void prog_main(void)
{
	i64 shmid, semid, msgid, addr, shmid2;
	put("=== probe6: SysV IPC ===\n");

	shmid = sc3(SYS_shmget, 0 /*IPC_PRIVATE*/, 4096, IPC_CREAT | 0600);
	show("shmget(IPC_PRIVATE,4096)", shmid);
	if (shmid >= 0) {
		addr = sc3(SYS_shmat, shmid, 0, 0);
		show("shmat", addr);
		show("shmctl(RMID)", sc3(SYS_shmctl, shmid, IPC_RMID, 0));
	}

	/* 命名 key：会走 libandroid-shmem 的 symlink 协调路径（_PATH_TMP） */
	shmid2 = sc3(SYS_shmget, 0x1234, 4096, IPC_CREAT | 0600);
	show("shmget(key=0x1234)", shmid2);
	if (shmid2 >= 0) {
		show("shmget(same key again)", sc3(SYS_shmget, 0x1234, 4096, IPC_CREAT | 0600));
		show("shmctl(RMID)", sc3(SYS_shmctl, shmid2, IPC_RMID, 0));
	}

	semid = sc3(SYS_semget, 0, 1, IPC_CREAT | 0600);
	show("semget(1)", semid);

	msgid = sc3(SYS_msgget, 0, IPC_CREAT | 0600, 0);
	show("msgget", msgid);

	put("=== done ===\n");
	sc1(SYS_exit, 0);
	for (;;) {}
}
#endif /* PROBE6_WRITE / PROBE6_READ */
