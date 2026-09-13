/* probe4.c - A2 investigation: reproduce apk's "preserve modification time"
 * failure for hardlinked entries, and map which PRoot path operation breaks.
 *
 * apk's installer does, per file:
 *     extract  ->  <dir>/.apk.<sha256>          (openat O_CREAT|O_WRONLY, write)
 *     utimensat(dirfd, ".apk.<sha>", times, AT_SYMLINK_NOFOLLOW)
 *     renameat(dirfd, ".apk.<sha>", dirfd, "<final name>")
 * and for hardlinked entries it first creates a hard link to an earlier entry
 * (linkat).  PRoot's --link2symlink rewrites link() into symlink + sidecar
 * ".proot-meta-file.*", which is what we see left behind in /usr/share/zoneinfo.
 *
 * This probe walks that exact sequence with raw syscalls and reports the first
 * failing step, for every flag combination that could matter.
 *
 * Build: clang --target=aarch64-linux-android21 -nostdlib -static -O1 -o probe4 probe4.c
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
#define SYS_write 1
#define SYS_close 3
#define SYS_openat 257
#define SYS_utimensat 280
#define SYS_renameat 264
#define SYS_linkat 265
#define SYS_unlinkat 263
#define SYS_mkdirat 258
#define SYS_exit 60
#define SYS_lstat_newfstatat 262
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
#define SYS_openat 56
#define SYS_utimensat 88
#define SYS_renameat 38
#define SYS_linkat 37
#define SYS_unlinkat 35
#define SYS_mkdirat 34
#define SYS_exit 93
#define SYS_lstat_newfstatat 79
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

static void show(const char *name, i64 ret)
{
	put(name); put(" = "); putnum(ret);
	if (ret == -2) put("   [ENOENT]");
	else if (ret == -22) put("   [EINVAL]");
	else if (ret == -9) put("   [EBADF]");
	else if (ret == -40) put("   [ELOOP]");
	else if (ret == -38) put("   [ENOSYS]");
	put("\n");
}

#define AT_FDCWD (-100)
#define AT_SYMLINK_NOFOLLOW 0x100
#define AT_EMPTY_PATH 0x1000
#define O_RDONLY 0
#define O_WRONLY 1
#define O_CREAT 0x40
#define O_TRUNC 0x200
#define O_DIRECTORY 0x10000
#define O_NOFOLLOW 0x20000
#define O_PATH 0x200000
#define O_CLOEXEC 0x80000
#define AT_REMOVEDIR 0x200

void prog_main(void);

#if defined(__x86_64__)
__asm__(".globl _start\n_start:\n  andq $-16, %rsp\n  call prog_main\n"
	"  movl $60, %eax\n  xorl %edi, %edi\n  syscall\n");
#else
__asm__(".globl _start\n_start:\n  bl prog_main\n  mov x0, #0\n"
	"  mov x8, #93\n  svc #0\n");
#endif

void prog_main(void)
{
	i64 dfd, ffd, ofd, r;
	long st[64];

	put("=== probe4: replicate apk's extract -> mtime -> link -> rename ===\n");
	sc1(SYS_mkdirat, 0);	/* no-op to keep syscall table honest */

	/* step 0: fresh working directory */
	sc4(SYS_openat, AT_FDCWD, (i64)"/root/p4dir", O_RDONLY | O_DIRECTORY, 0);
	sc3(SYS_mkdirat, AT_FDCWD, (i64)"/root/p4dir", 0755);

	put("--- opening the directory (apk keeps a dirfd per directory) ---\n");
	/* report the flag variants, but use the plain O_RDONLY fd as the working
	 * dirfd so the rest of the sequence is meaningful even if one fails */
	show("openat(/root/p4dir, RDONLY)", sc4(SYS_openat, AT_FDCWD, (i64)"/root/p4dir", O_RDONLY, 0));
	show("openat(/root/p4dir, RDONLY|O_DIRECTORY)",
	     sc4(SYS_openat, AT_FDCWD, (i64)"/root/p4dir", O_RDONLY | O_DIRECTORY, 0));
	show("openat(/root/p4dir, RDONLY|O_DIRECTORY|O_CLOEXEC)",
	     sc4(SYS_openat, AT_FDCWD, (i64)"/root/p4dir", O_RDONLY | O_DIRECTORY | O_CLOEXEC, 0));
	show("openat(/root/p4dir, O_PATH)",
	     sc4(SYS_openat, AT_FDCWD, (i64)"/root/p4dir", O_PATH, 0));
	show("openat(/root/p4dir, O_PATH|O_DIRECTORY)",
	     sc4(SYS_openat, AT_FDCWD, (i64)"/root/p4dir", O_PATH | O_DIRECTORY, 0));
	show("working dirfd = openat(RDONLY)",
	     dfd = sc4(SYS_openat, AT_FDCWD, (i64)"/root/p4dir", O_RDONLY, 0));
	if (dfd < 0) {
		put("!! no usable dirfd, aborting\n");
		sc1(SYS_exit, 1);
	}

	put("--- apk step 1: extract into .apk.<hash> (dirfd-relative) ---\n");
	show("openat(dfd, \".apk.aaa\", O_CREAT|O_WRONLY|O_TRUNC)",
	     ffd = sc4(SYS_openat, dfd, (i64)".apk.aaa", O_CREAT | O_WRONLY | O_TRUNC, 0644));
	if (ffd >= 0) {
		sc3(SYS_write, ffd, (i64)"hello", 5);
		sc1(SYS_close, ffd);
	}

	put("--- apk step 2: preserve mtime on the temp name ---\n");
	show("utimensat(dfd, \".apk.aaa\", NULL, AT_SYMLINK_NOFOLLOW)",
	     sc4(SYS_utimensat, dfd, (i64)".apk.aaa", 0, AT_SYMLINK_NOFOLLOW));
	show("utimensat(dfd, \".apk.aaa\", NULL, 0)",
	     sc4(SYS_utimensat, dfd, (i64)".apk.aaa", 0, 0));
	show("newfstatat(dfd, \".apk.aaa\", NOFOLLOW)",
	     sc4(SYS_lstat_newfstatat, dfd, (i64)".apk.aaa", (i64)st, AT_SYMLINK_NOFOLLOW));
	show("openat(dfd, \".apk.aaa\", O_PATH)",
	     ofd = sc4(SYS_openat, dfd, (i64)".apk.aaa", O_PATH, 0));
	if (ofd >= 0) {
		show("utimensat(ofd, \"\", NULL, AT_EMPTY_PATH)",
		     sc4(SYS_utimensat, ofd, (i64)"", 0, AT_EMPTY_PATH));
		sc1(SYS_close, ofd);
	}

	put("--- apk step 3: hardlink to an earlier entry (tzdata's case) ---\n");
	show("linkat(dfd, \".apk.aaa\" -> \".apk.bbb\")",
	     sc6(SYS_linkat, dfd, (i64)".apk.aaa", dfd, (i64)".apk.bbb", 0, 0));
	show("newfstatat(dfd, \".apk.bbb\", NOFOLLOW)",
	     sc4(SYS_lstat_newfstatat, dfd, (i64)".apk.bbb", (i64)st, AT_SYMLINK_NOFOLLOW));
	show("utimensat(dfd, \".apk.bbb\", NULL, AT_SYMLINK_NOFOLLOW)",
	     sc4(SYS_utimensat, dfd, (i64)".apk.bbb", 0, AT_SYMLINK_NOFOLLOW));
	show("utimensat(dfd, \".apk.bbb\", NULL, 0)   [follows l2s link]",
	     sc4(SYS_utimensat, dfd, (i64)".apk.bbb", 0, 0));

	put("--- apk step 4: rename temp -> final name ---\n");
	show("renameat(dfd, \".apk.aaa\" -> \"final1\")",
	     sc4(SYS_renameat, dfd, (i64)".apk.aaa", dfd, (i64)"final1"));
	show("renameat(dfd, \".apk.bbb\" -> \"final2\")",
	     sc4(SYS_renameat, dfd, (i64)".apk.bbb", dfd, (i64)"final2"));
	show("utimensat(dfd, \"final1\", NULL, 0)", sc4(SYS_utimensat, dfd, (i64)"final1", 0, 0));
	show("utimensat(dfd, \"final2\", NULL, 0)", sc4(SYS_utimensat, dfd, (i64)"final2", 0, 0));

	put("--- cleanup / listing evidence ---\n");
	show("newfstatat(dfd, \"final2\", NOFOLLOW)",
	     sc4(SYS_lstat_newfstatat, dfd, (i64)"final2", (i64)st, AT_SYMLINK_NOFOLLOW));
	show("unlinkat(dfd, \"final1\")", sc3(SYS_unlinkat, dfd, (i64)"final1", 0));
	show("unlinkat(dfd, \"final2\")", sc3(SYS_unlinkat, dfd, (i64)"final2", 0));
	if (dfd >= 0) sc1(SYS_close, dfd);

	put("=== probe4 done ===\n");
	sc1(SYS_exit, 0);
	for (;;) {}
}
