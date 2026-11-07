#!/usr/bin/env python3
# Every second, each ggml-rpc-server / llama-server thread: thrdump.py <seconds> <out>
# Line: t(s, CLOCK_MONOTONIC) pid tid cpu(last ran on) cpu_ticks(utime+stime, cumulative) allowed(Cpus_allowed_list)
import os, sys, time
secs, out = float(sys.argv[1]), open(sys.argv[2], "w")
names = {"ggml-rpc-server", "llama-server"}
t_end = time.monotonic() + secs
while time.monotonic() < t_end:
    now = time.monotonic()
    for pid in os.listdir("/proc"):
        if not pid.isdigit():
            continue
        try:
            if open(f"/proc/{pid}/comm").read().strip() not in names:
                continue
            for tid in os.listdir(f"/proc/{pid}/task"):
                st = open(f"/proc/{pid}/task/{tid}/stat").read()
                f = st[st.rindex(")") + 2:].split()
                allowed = next(l.split()[1] for l in open(f"/proc/{pid}/task/{tid}/status") if l.startswith("Cpus_allowed_list"))
                out.write(f"{now:.3f} {pid} {tid} {f[36]} {int(f[11]) + int(f[12])} {allowed}\n")
        except (OSError, StopIteration, ValueError):
            pass
    out.flush()
    time.sleep(1)
