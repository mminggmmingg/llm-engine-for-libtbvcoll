#!/usr/bin/env python3
# Find threads that run in ~1 s periodic bursts: periodic.py <seconds> <period ms> [name regex]
# Samples /proc/*/task/*/schedstat (ns of CPU) for matching threads, then prints threads whose CPU time comes in bursts
# >= 1 ms, with burst size, burst spacing and the CPU they ran on.
import os, re, sys, time
secs, per = float(sys.argv[1]), float(sys.argv[2]) / 1000
rx = re.compile(sys.argv[3] if len(sys.argv) > 3 else r"kworker|irq/|ksoftirqd|kcompactd|kswapd|khugepaged|rcu|migration|watchdog|kthreadd|thunderbolt|amd|acpi")
tasks = []
for p in os.listdir("/proc"):
    if not p.isdigit():
        continue
    try:
        for t in os.listdir(f"/proc/{p}/task"):
            name = open(f"/proc/{p}/task/{t}/comm").read().strip()
            if rx.search(name):
                tasks.append((t, name, os.open(f"/proc/{p}/task/{t}/schedstat", os.O_RDONLY)))
    except OSError:
        pass
hist = {t: [] for t, _, _ in tasks}
end = time.monotonic() + secs
while time.monotonic() < end:
    now = time.monotonic()
    for t, _, fd in tasks:
        try:
            ns = int(os.pread(fd, 64, 0).split()[0])
        except OSError:
            continue
        hist[t].append((now, ns))
    time.sleep(per)
cpu_of = {}
for t, name, _ in tasks:
    try:
        s = open(f"/proc/{t}/stat").read()
        cpu_of[t] = int(s[s.rindex(")") + 2:].split()[36])
    except OSError:
        cpu_of[t] = -1
rows = []
for t, name, _ in tasks:
    h = hist[t]
    bursts = []  # (start time, ns) of runs of consecutive busy samples
    cur = None
    for (t0, a), (t1, b) in zip(h, h[1:]):
        d = b - a
        if d > 0:
            cur = [t0, d] if cur is None else [cur[0], cur[1] + d]
        elif cur is not None:
            bursts.append(cur)
            cur = None
    big = [b for b in bursts if b[1] >= 1_000_000]
    if len(big) >= 2:
        gaps = [round((y[0] - x[0]) * 1000) for x, y in zip(big, big[1:])]
        rows.append((len(big), t, name, cpu_of[t], [round(b[1] / 1e6, 1) for b in big][:12], gaps[:12]))
for n, t, name, cpu, sizes, gaps in sorted(rows, reverse=True)[:25]:
    print(f"{name:28s} tid {t:>8s} cpu {cpu:2d} bursts>=1ms {n:3d} ms {sizes} gaps_ms {gaps}")
