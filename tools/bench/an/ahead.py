# 서버 호스트가 GPU 보다 얼마나 앞서는가: AR seq 마다 (GPU 복사 시작 시각 - 그 AR 명령을 호스트가 끝낸 시각), 그리고 그 앞 부분그래프 GRAPH_RECOMPUTE 명령 끝
import os, struct, sys, statistics as st, bisect
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gpupos import recs
for p in sys.argv[1:]:
    R = recs(p)
    cal = sorted((t[1], t[0]) for typ, a, b, t in R if typ == 5)   # (gpu tick, host us)
    ticks = [c[0] for c in cal]
    def g2h(g):
        i = bisect.bisect_left(ticks, g); i = min(max(i, 1), len(cal) - 1)
        (g0, h0), (g1, h1) = cal[i - 1], cal[i]
        return h0 + (g - g0) * (h1 - h0) / (g1 - g0)
    gpu = {a: t for typ, a, b, t in R if typ == 4}
    ar = {a: t for typ, a, b, t in R if typ == 2}
    # 명령 기록: CMD(1) a=command, t: wait start, start, end — AR 명령(21) 순서와 seq 를 짝지음
    cmds = [(a, t) for typ, a, b, t in R if typ == 1]
    lead = []; lead_g = []
    last_gr_end = None
    for c, t in cmds:
        if c in (10, 16):
            last_gr_end = t[2]
    for q, t in ar.items():
        if q in gpu and len(cal) > 2:
            gs = g2h(gpu[q][0])               # GPU 복사 시작(호스트 시각)
            lead.append(gs - t[5])            # AR 명령 return 뒤 GPU 가 거기 닿기까지
    lead.sort()
    n = len(lead)
    print(p.split('/')[-2], p.split('/')[-1], f'n={n} GPU copy-out start - host AR return (us): p10 {lead[n//10]:.0f} med {lead[n//2]:.0f} p90 {lead[n*9//10]:.0f}  (<0: host late)')
