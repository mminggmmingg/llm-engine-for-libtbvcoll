#!/usr/bin/env python3
# 11-10: 클라이언트(초안 GPU) rocprofv3 kernel_trace 를 시간 간격으로 덩어리(초안 1단계)로 나눠 단계별 커널 수·바쁜 시간·벽 시간·빈틈을 센다
import csv, sys, collections, statistics as st
rows = []
for r in csv.DictReader(open(sys.argv[1])):
    rows.append((int(r["Start_Timestamp"]), int(r["End_Timestamp"]), r["Kernel_Name"]))
rows.sort()
GAP = float(sys.argv[2]) if len(sys.argv) > 2 else 300e3  # ns: 이 이상 비면 새 덩어리
groups, cur = [], [rows[0]]
for x in rows[1:]:
    if x[0] - max(e for _, e, _ in cur[-8:]) > GAP: groups.append(cur); cur = [x]
    else: cur.append(x)
groups.append(cur)
def short(n): return n.split("(")[0].replace("void ", "")[:60]
bysz = collections.defaultdict(list)
for g in groups: bysz[len(g)].append(g)
print(f"dispatches {len(rows)}, groups {len(groups)} (gap>{GAP/1e3:.0f} us)")
print("size  count  wall_us(med)  busy_us(med)  idle_us(med)")
for n, gs in sorted(bysz.items(), key=lambda kv: -len(kv[1]))[:8]:
    wall = [g[-1][1] - g[0][0] for g in gs]; busy = [sum(e - s for s, e, _ in g) for g in gs]
    print(f"{n:5d} {len(gs):6d} {st.median(wall)/1e3:12.1f} {st.median(busy)/1e3:13.1f} {st.median([w-b for w,b in zip(wall,busy)])/1e3:13.1f}")
n0 = max(bysz, key=lambda k: len(bysz[k])); gs = bysz[n0]
agg = collections.defaultdict(lambda: [0, 0.0])
for g in gs:
    for s, e, k in g: agg[short(k)][0] += 1; agg[short(k)][1] += (e - s)
print(f"\nmost common group size {n0}: per-group kernel time by name (us)")
for k, (c, t) in sorted(agg.items(), key=lambda kv: -kv[1][1])[:18]:
    print(f"{t/len(gs)/1e3:8.1f} us  x{c/len(gs):5.1f}  {k}")
gaps = []
for g in gs:
    for a, b in zip(g, g[1:]): gaps.append(b[0] - a[1])
gaps.sort(); print(f"\nkernel-to-kernel gap in group: med {st.median(gaps)/1e3:.1f} us, p90 {gaps[int(.9*len(gaps))]/1e3:.1f} us, sum/group {sum(max(0,x) for x in gaps)/len(gs)/1e3:.1f} us")
# 덩어리 사이 빈틈(서버 쪽 시간)
inter = [b[0][0] - a[-1][1] for a, b in zip(groups, groups[1:])]
inter.sort(); print(f"between groups: med {st.median(inter)/1e3:.1f} us")
