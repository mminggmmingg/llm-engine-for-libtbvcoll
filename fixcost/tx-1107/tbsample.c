// Sample Thunderbolt NHI interrupt counts and the scheduler stats of the threads around them:
//   tbsample <seconds> <period us> <out> [process name ...]
// Every period: each thunderbolt vector's interrupt count (/sys/kernel/irq/N/per_cpu_count), and /proc/<tid>/schedstat of
// every kworker and ksoftirqd bound to a CPU that takes those vectors, plus every thread of the named processes.
// Threads and vectors are looked up again every second. Lines (CLOCK_MONOTONIC us, the clock of ggml_time_us):
//   I <t> <irq> <cpu> <delta>                 the vector took <delta> interrupts since the last sample
//   S <t> <tid> <drun us> <dwait us> <dslices> the thread ran / waited on a runqueue that much more (wait is added when
//                                             the thread gets the CPU, so <t> is about when its wait ended). Process
//                                             threads only when they waited or switched (a spinner's run time is noise)
//   T <t> <tid> <cpu> <comm>                  thread found (cpu = the CPU a kworker/ksoftirqd is bound to, else -1)
//   V <t> <irq> <cpu> <name>                  vector found
// No root needed. Build: gcc -O2 -o tbsample tbsample.c
#define _GNU_SOURCE
#include <dirent.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#define MAXV 64
#define MAXT 1024

struct vec { int irq, cpu, fd; long long last; };
struct thr { int tid, cpu, fd; long long run, wait, sl; };

static struct vec V[MAXV]; static int nv;
static struct thr T[MAXT]; static int nt;
static FILE *out;
static char **names; static int nnames;

static long long now_us(void) {
    struct timespec ts; clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec * 1000000LL + ts.tv_nsec / 1000;
}

static int read_small(const char *path, char *buf, int n) {
    int fd = open(path, O_RDONLY); if (fd < 0) return -1;
    int r = read(fd, buf, n - 1); close(fd);
    if (r < 0) return -1;
    buf[r] = 0; return r;
}

static long long sum_counts(int fd) {
    char buf[1024]; int r = pread(fd, buf, sizeof buf - 1, 0); if (r <= 0) return -1;
    buf[r] = 0; long long s = 0; char *p = buf;
    while (*p) { s += strtoll(p, &p, 10); if (*p == ',') p++; else break; }
    return s;
}

static int cpu_used(int c) { for (int i = 0; i < nv; i++) if (V[i].cpu == c) return 1; return 0; }
static int have_tid(int tid) { for (int i = 0; i < nt; i++) if (T[i].tid == tid) return 1; return 0; }

static void add_thr(int tid, int cpu, const char *stat_path, const char *comm, long long t) {
    if (nt >= MAXT || have_tid(tid)) return;
    int fd = open(stat_path, O_RDONLY); if (fd < 0) return;
    char buf[128]; int r = pread(fd, buf, sizeof buf - 1, 0); if (r <= 0) { close(fd); return; }
    buf[r] = 0;
    struct thr *x = &T[nt++]; x->tid = tid; x->cpu = cpu; x->fd = fd;
    sscanf(buf, "%lld %lld %lld", &x->run, &x->wait, &x->sl);
    fprintf(out, "T %lld %d %d %s\n", t, tid, cpu, comm);
}

static void scan(long long t) {
    // vectors
    FILE *f = fopen("/proc/interrupts", "r"); char line[4096];
    if (f) {
        while (fgets(line, sizeof line, f)) {
            if (!strstr(line, "thunderbolt")) continue;
            int irq = atoi(line), known = 0;
            for (int i = 0; i < nv; i++) if (V[i].irq == irq) known = 1;
            if (known || nv >= MAXV) continue;
            char p[128], b[64]; snprintf(p, sizeof p, "/proc/irq/%d/effective_affinity_list", irq);
            int cpu = read_small(p, b, sizeof b) > 0 ? atoi(b) : -1;
            snprintf(p, sizeof p, "/sys/kernel/irq/%d/per_cpu_count", irq);
            int fd = open(p, O_RDONLY); if (fd < 0) continue;
            V[nv] = (struct vec){ irq, cpu, fd, sum_counts(fd) };
            nv++;
            char *nl = strchr(line, '\n'); if (nl) *nl = 0;
            fprintf(out, "V %lld %d %d %s\n", t, irq, cpu, strrchr(line, ' ') ? strrchr(line, ' ') + 1 : "?");
        }
        fclose(f);
    }
    // threads
    DIR *d = opendir("/proc"); struct dirent *e;
    if (!d) return;
    while ((e = readdir(d))) {
        int pid = atoi(e->d_name); if (pid <= 0) continue;
        char p[256], comm[64];
        snprintf(p, sizeof p, "/proc/%d/comm", pid);
        if (read_small(p, comm, sizeof comm) <= 0) continue;
        char *nl = strchr(comm, '\n'); if (nl) *nl = 0;
        int cpu = -1;
        if ((sscanf(comm, "kworker/%d:", &cpu) == 1 || sscanf(comm, "ksoftirqd/%d", &cpu) == 1) && cpu_used(cpu)) {
            snprintf(p, sizeof p, "/proc/%d/schedstat", pid);
            add_thr(pid, cpu, p, comm, t);
            continue;
        }
        for (int k = 0; k < nnames; k++) {
            if (strcmp(comm, names[k]) != 0) continue;
            snprintf(p, sizeof p, "/proc/%d/task", pid);
            DIR *td = opendir(p); struct dirent *te;
            if (!td) break;
            while ((te = readdir(td))) {
                int tid = atoi(te->d_name); if (tid <= 0) continue;
                char sp[256], tc[64], cp[256];
                snprintf(cp, sizeof cp, "/proc/%d/task/%d/comm", pid, tid);
                if (read_small(cp, tc, sizeof tc) <= 0) continue;
                nl = strchr(tc, '\n'); if (nl) *nl = 0;
                snprintf(sp, sizeof sp, "/proc/%d/task/%d/schedstat", pid, tid);
                add_thr(tid, -1, sp, tc, t);
            }
            closedir(td);
            break;
        }
    }
    closedir(d);
}

int main(int argc, char **argv) {
    if (argc < 4) { fprintf(stderr, "usage: %s <seconds> <period us> <out> [process name ...]\n", argv[0]); return 2; }
    double secs = atof(argv[1]); long per = atol(argv[2]);
    out = fopen(argv[3], "w"); if (!out) { perror(argv[3]); return 1; }
    static char obuf[1 << 24]; setvbuf(out, obuf, _IOFBF, sizeof obuf);
    names = argv + 4; nnames = argc - 4;
    long long t0 = now_us(), next_scan = t0;
    struct timespec ts; clock_gettime(CLOCK_MONOTONIC, &ts);
    for (;;) {
        long long t = now_us();
        if (t - t0 > (long long) (secs * 1e6)) break;
        if (t >= next_scan) { scan(t); next_scan = t + 1000000; }
        for (int i = 0; i < nv; i++) {
            long long c = sum_counts(V[i].fd);
            if (c > V[i].last) { fprintf(out, "I %lld %d %d %lld\n", t, V[i].irq, V[i].cpu, c - V[i].last); V[i].last = c; }
        }
        for (int i = 0; i < nt; i++) {
            char buf[128]; int r = pread(T[i].fd, buf, sizeof buf - 1, 0);
            if (r <= 0) { close(T[i].fd); T[i] = T[--nt]; i--; continue; }
            buf[r] = 0; long long run, wait, sl;
            if (sscanf(buf, "%lld %lld %lld", &run, &wait, &sl) != 3) continue;
            // kworkers / ksoftirqd: every change; process threads (busy spinners): only when they waited or switched
            if (T[i].cpu >= 0 ? (run != T[i].run || wait != T[i].wait) : (wait != T[i].wait || sl != T[i].sl)) {
                fprintf(out, "S %lld %d %lld %lld %lld\n", t, T[i].tid, (run - T[i].run) / 1000, (wait - T[i].wait) / 1000, sl - T[i].sl);
                T[i].run = run; T[i].wait = wait; T[i].sl = sl;
            }
        }
        ts.tv_nsec += per * 1000;
        while (ts.tv_nsec >= 1000000000) { ts.tv_nsec -= 1000000000; ts.tv_sec++; }
        clock_nanosleep(CLOCK_MONOTONIC, TIMER_ABSTIME, &ts, NULL);
    }
    fclose(out);
    return 0;
}
