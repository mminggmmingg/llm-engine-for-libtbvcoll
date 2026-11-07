#!/usr/bin/env python3
# Log CPU bursts of per-CPU kworkers: kwburst.py <seconds> <period ms> <out>
# Each line: start_us(CLOCK_MONOTONIC) end_us run_us comm  — one per run of consecutive samples where the thread used CPU,
# kept when it used >= 300 us. Per-CPU kworkers are bound, so the CPU is the number in the name (kworker/<cpu>:<n>).
import os, re, sys, time
secs, per, out = float(sys.argv[1]), float(sys.argv[2]) / 1000, sys.argv[3]
rx = re.compile(r"^kworker/\d+:")
fds, last, cur = {}, {}, {}

def scan():
    for t in os.listdir("/proc"):
        if not t.isdigit() or t in fds:
            continue
        try:
            if rx.match(open(f"/proc/{t}/comm").read()):
                fds[t] = os.open(f"/proc/{t}/schedstat", os.O_RDONLY)
        except OSError:
            pass

def comm(t):
    try:
        return open(f"/proc/{t}/comm").read().strip()
    except OSError:
        return "?"

with open(out, "w") as f:
    end = time.monotonic() + secs
    nscan = 0
    while time.monotonic() < end:
        if time.monotonic() >= nscan:
            scan()
            nscan = time.monotonic() + 1
        now = int(time.clock_gettime(time.CLOCK_MONOTONIC) * 1e6)
        for t, fd in list(fds.items()):
            try:
                ns = int(os.pread(fd, 64, 0).split()[0])
            except OSError:
                os.close(fd); del fds[t]; continue
            d = ns - last.get(t, ns)
            last[t] = ns
            if d > 0:
                c = cur.get(t)
                cur[t] = [now - int(per * 1e6), now, d] if c is None else [c[0], now, c[2] + d]
            elif t in cur:
                s, e, r = cur.pop(t)
                if r >= 300_000:
                    f.write(f"{s} {e} {r // 1000} {comm(t)}\n")
        time.sleep(per)
