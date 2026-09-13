/*
 * libfix_seccomp.c - LD_PRELOAD shim for a PRoot container running inside an
 * Android *application* process.
 *
 * Everything here was proved by measurement on device (OnePlus PLC110 /
 * Android 16 / arm64) and on the x86_64 emulator; see
 * APK_TEMPORARY_ERROR_FIX_PLAN.md for the raw evidence.
 *
 * WHAT IS HERE, AND WHY
 * ---------------------
 * 1. utimensat()                                   - BOTH architectures
 *    Android refuses link(2) on app data (measured: dropping --link2symlink
 *    makes apk fail with "Failed to create ...: Permission denied"), so PRoot
 *    emulates hard links as symlink + hidden bookkeeping entry
 *    (".proot-meta-file.<name>", PROOT_L2S_DIR).  Resolving *through* such an
 *    entry is refused, so a following utimensat() - exactly what apk calls to
 *    "preserve modification time" on a freshly extracted file - returns ENOENT
 *    and the package is marked broken:
 *
 *      ERROR: Failed to preserve modification time on usr/share/zoneinfo/Africa/.apk.<sha>: No such file or directory
 *
 *    Retrying with AT_SYMLINK_NOFOLLOW stamps the entry itself, which is the
 *    closest available approximation of hardlink semantics.
 *
 * 2. poll / select / pipe / dup2                   - x86_64 ONLY
 *    Android's app seccomp policy answers the legacy spelling of these calls
 *    with ENOSYS (bionic itself uses ppoll/pselect6/pipe2/dup3), and musl
 *    prefers the legacy spelling whenever the architecture has it:
 *    poll()/select() are literal #ifdef SYS_poll / SYS_select choices, pipe()
 *    and dup2() likewise.  Forwarding them to the modern syscall fixes it.
 *    Measured ENOSYS on x86_64 for poll and select; pipe/dup2 belong to the
 *    same legacy family and are kept for the same reason.
 *    arm64 has none of these syscalls in its (asm-generic) table, so libc
 *    never issues them and nothing is overridden there.
 *
 * WHAT WAS DELIBERATELY REMOVED (it was a no-op or based on a wrong guess)
 * ----------------------------------------------------------------------
 *   fork / vfork      - musl already implements both with clone(SIGCHLD);
 *                       the override duplicated it (and replaced vfork with
 *                       fork, losing the optimised path for nothing).
 *   stat / lstat /    - identical to what musl issues itself (musl's stat
 *   fstat / fstatat     family *is* the newfstatat/fstat syscall pair), so
 *   *64 variants        these only cost an indirection.
 *   fstatat("" ...)   - the old "PRoot returns EINVAL for an empty path"
 *                       workaround: measured on device, AT_EMPTY_PATH works
 *                       (`newfstatat(fd,"",st,AT_EMPTY_PATH) = 0`), and the
 *                       ENOENT for an empty path *without* that flag is the
 *                       kernel's correct behaviour, not a PRoot bug.
 */

#define _GNU_SOURCE

typedef long ssize_t;
typedef unsigned long size_t;
typedef int pid_t;
typedef unsigned long nfds_t;

struct pollfd {
    int fd;
    short events;
    short revents;
};

struct timespec {
    long tv_sec;
    long tv_nsec;
};

struct timeval {
    long tv_sec;
    long tv_usec;
};

extern int *__errno_location(void) __attribute__((weak));

#if defined(__x86_64__)

static inline long my_syscall2(long n, long a1, long a2) {
    long ret;
    __asm__ __volatile__ ("syscall"
        : "=a"(ret)
        : "a"(n), "D"(a1), "S"(a2)
        : "rcx", "r11", "memory"
    );
    return ret;
}

static inline long my_syscall3(long n, long a1, long a2, long a3) {
    long ret;
    __asm__ __volatile__ ("syscall"
        : "=a"(ret)
        : "a"(n), "D"(a1), "S"(a2), "d"(a3)
        : "rcx", "r11", "memory"
    );
    return ret;
}

static inline long my_syscall4(long n, long a1, long a2, long a3, long a4) {
    long ret;
    register long r10 __asm__("r10") = a4;
    __asm__ __volatile__ ("syscall"
        : "=a"(ret)
        : "a"(n), "D"(a1), "S"(a2), "d"(a3), "r"(r10)
        : "rcx", "r11", "memory"
    );
    return ret;
}

static inline long my_syscall6(long n, long a1, long a2, long a3, long a4, long a5, long a6) {
    long ret;
    register long r10 __asm__("r10") = a4;
    register long r8 __asm__("r8") = a5;
    register long r9 __asm__("r9") = a6;
    __asm__ __volatile__ ("syscall"
        : "=a"(ret)
        : "a"(n), "D"(a1), "S"(a2), "d"(a3), "r"(r10), "r"(r8), "r"(r9)
        : "rcx", "r11", "memory"
    );
    return ret;
}

#define SYS_utimensat 280
#define SYS_ppoll 271
#define SYS_pipe2 293
#define SYS_dup3 292

#elif defined(__aarch64__)

static inline long my_syscall2(long n, long a1, long a2) {
    register long x8 __asm__("x8") = n;
    register long x0 __asm__("x0") = a1;
    register long x1 __asm__("x1") = a2;
    __asm__ __volatile__ ("svc #0" : "+r"(x0) : "r"(x8), "r"(x1) : "memory");
    return x0;
}

static inline long my_syscall3(long n, long a1, long a2, long a3) {
    register long x8 __asm__("x8") = n;
    register long x0 __asm__("x0") = a1;
    register long x1 __asm__("x1") = a2;
    register long x2 __asm__("x2") = a3;
    __asm__ __volatile__ ("svc #0" : "+r"(x0) : "r"(x8), "r"(x1), "r"(x2) : "memory");
    return x0;
}

static inline long my_syscall6(long n, long a1, long a2, long a3, long a4, long a5, long a6) {
    register long x8 __asm__("x8") = n;
    register long x0 __asm__("x0") = a1;
    register long x1 __asm__("x1") = a2;
    register long x2 __asm__("x2") = a3;
    register long x3 __asm__("x3") = a4;
    register long x4 __asm__("x4") = a5;
    register long x5 __asm__("x5") = a6;
    __asm__ __volatile__ ("svc #0" : "+r"(x0)
        : "r"(x8), "r"(x1), "r"(x2), "r"(x3), "r"(x4), "r"(x5) : "memory");
    return x0;
}

#define SYS_utimensat 88
#define SYS_ppoll 73

#endif

#define AT_SYMLINK_NOFOLLOW 0x100
#define ENOENT 2

static inline int set_errno_and_return(long ret) {
    if (ret < 0) {
        if (__errno_location) {
            *__errno_location() = (int)(-ret);
        }
        return -1;
    }
    return (int)ret;
}

/* -------------------------------------------------------------------------
 * utimensat(): survive PRoot's --link2symlink hardlink stand-ins.
 * ------------------------------------------------------------------------- */
__attribute__((visibility("default")))
int utimensat(int dirfd, const char *path, const void *times, int flags) {
    long ret = my_syscall6(SYS_utimensat, (long)dirfd, (long)path,
                           (long)times, (long)flags, 0, 0);
    if (ret == -ENOENT && path != 0 && path[0] != '\0' &&
        (flags & AT_SYMLINK_NOFOLLOW) == 0) {
        long retry = my_syscall6(SYS_utimensat, (long)dirfd, (long)path,
                                 (long)times,
                                 (long)(flags | AT_SYMLINK_NOFOLLOW), 0, 0);
        if (retry >= 0) {
            return 0;
        }
    }
    return set_errno_and_return(ret);
}

#if defined(__x86_64__)

/* -------------------------------------------------------------------------
 * Legacy wait/descriptor syscalls that only x86_64 still has.
 * ------------------------------------------------------------------------- */
#define POLLIN_L 0x001
#define POLLPRI_L 0x002
#define POLLOUT_L 0x004
#define POLLERR_L 0x008
#define POLLHUP_L 0x010
#define FD_SETSIZE_L 1024
#define F_GETFL_L 3

typedef unsigned long fd_mask_l;

__attribute__((visibility("default")))
int poll(struct pollfd *fds, nfds_t nfds, int timeout) {
    struct timespec ts;
    struct timespec *pts = (struct timespec *)0;
    if (timeout >= 0) {
        ts.tv_sec = timeout / 1000;
        ts.tv_nsec = (long)(timeout % 1000) * 1000000L;
        pts = &ts;
    }
    long ret = my_syscall6(SYS_ppoll, (long)fds, (long)nfds, (long)pts, 0, 0, 0);
    return set_errno_and_return(ret);
}

static int fd_is_set(fd_mask_l *set, int fd) {
    return (set[fd / (8 * (int)sizeof(fd_mask_l))] >>
            (fd % (8 * (int)sizeof(fd_mask_l)))) & 1UL;
}

static void fd_set_bit(fd_mask_l *set, int fd) {
    set[fd / (8 * (int)sizeof(fd_mask_l))] |= 1UL << (fd % (8 * (int)sizeof(fd_mask_l)));
}

static void fd_zero_bits(fd_mask_l *set, int nfds) {
    int words = (nfds + (int)(8 * sizeof(fd_mask_l)) - 1) / (int)(8 * sizeof(fd_mask_l));
    int i;
    for (i = 0; i < words; i++) set[i] = 0;
}

/* select() on top of ppoll(): musl issues the legacy select(2) syscall here,
 * which an app process may not use.  libfetch (apk's downloader) calls
 * select() to wait for a writable socket and, on failure, returns an error
 * without recording an error code - which apk reports as "IO ERROR". */
__attribute__((visibility("default")))
int select(int nfds, fd_mask_l *readfds, fd_mask_l *writefds,
           fd_mask_l *exceptfds, void *timeout) {
    struct pollfd pfds[FD_SETSIZE_L];
    struct timespec ts;
    struct timespec *tsp = (struct timespec *)0;
    struct timeval *tv = (struct timeval *)timeout;
    int n = 0, i, ready = 0;
    long ret;

    if (nfds < 0 || nfds > FD_SETSIZE_L) {
        if (__errno_location) *__errno_location() = 22 /* EINVAL */;
        return -1;
    }
    if (tv) {
        if (tv->tv_sec < 0 || tv->tv_usec < 0 || tv->tv_usec >= 1000000L) {
            if (__errno_location) *__errno_location() = 22;
            return -1;
        }
        ts.tv_sec = tv->tv_sec;
        ts.tv_nsec = tv->tv_usec * 1000L;
        tsp = &ts;
    }

    for (i = 0; i < nfds; i++) {
        short ev = 0;
        if (readfds && fd_is_set(readfds, i)) ev |= POLLIN_L;
        if (writefds && fd_is_set(writefds, i)) ev |= POLLOUT_L;
        if (exceptfds && fd_is_set(exceptfds, i)) ev |= POLLPRI_L;
        if (!ev) continue;
        pfds[n].fd = i;
        pfds[n].events = ev;
        pfds[n].revents = 0;
        n++;
    }

    ret = my_syscall6(SYS_ppoll, (long)pfds, (long)n, (long)tsp, 0, 0, 0);
    if (ret < 0) {
        if (__errno_location) *__errno_location() = (int)(-ret);
        return -1;
    }

    if (readfds) fd_zero_bits(readfds, nfds);
    if (writefds) fd_zero_bits(writefds, nfds);
    if (exceptfds) fd_zero_bits(exceptfds, nfds);

    for (i = 0; i < n; i++) {
        short re = pfds[i].revents;
        if (!re) continue;
        ready++;
        if (readfds && (re & (POLLIN_L | POLLHUP_L | POLLERR_L))) fd_set_bit(readfds, pfds[i].fd);
        if (writefds && (re & (POLLOUT_L | POLLHUP_L | POLLERR_L))) fd_set_bit(writefds, pfds[i].fd);
        if (exceptfds && (re & POLLPRI_L)) fd_set_bit(exceptfds, pfds[i].fd);
    }
    return ready;
}

__attribute__((visibility("default")))
int pipe(int pipefd[2]) {
    long ret = my_syscall2(SYS_pipe2, (long)pipefd, 0);
    return set_errno_and_return(ret);
}

__attribute__((visibility("default")))
int dup2(int oldfd, int newfd) {
    if (oldfd == newfd) {
        long ret = my_syscall3(72 /* fcntl */, (long)oldfd, (long)F_GETFL_L, 0);
        if (ret < 0) return set_errno_and_return(ret);
        return oldfd;
    }
    long ret = my_syscall3(SYS_dup3, (long)oldfd, (long)newfd, 0);
    return set_errno_and_return(ret);
}

#endif /* __x86_64__ */
