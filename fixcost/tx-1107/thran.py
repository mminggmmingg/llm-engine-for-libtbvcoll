# per thread in thrdump: allowed CPUs, CPU ticks used (rate), share of samples on TB CPUs
import sys, collections
TB = {2,3,4,5,6,21,22,23,24,30}
d = collections.defaultdict(list)
for line in open(sys.argv[1]):
    t, pid, tid, cpu, ticks, allowed = line.split()
    d[(pid, tid)].append((float(t), int(cpu), int(ticks), allowed))
rows = []
for (pid, tid), v in d.items():
    if len(v) < 5: continue
    dt = v[-1][0] - v[0][0]; use = (v[-1][2] - v[0][2]) / 100 / dt if dt > 0 else 0
    ontb = sum(c in TB for _, c, _, _ in v) / len(v)
    rows.append((use, pid, tid, v[-1][3], ontb, len(v)))
rows.sort(reverse=True)
print("cpu_use pid tid allowed on_TB_cpu_share samples")
for r in rows[:14]: print(f"{r[0]:.2f} {r[1]} {r[2]} {r[3]} {r[4]:.2f} {r[5]}")
