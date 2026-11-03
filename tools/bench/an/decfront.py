# llama_decode 앞부분(첫 ubatch 전) 단계별 시간: DECODE 기록 t[2..5] + UBATCH 기록 — decfront.py <client.ring>
import sys, struct
def recs(p):
    b = open(p, 'rb').read(); frm = struct.unpack_from('<Q', b, 4096)[0]; out = []
    for k in range((len(b) - 4104) // 64):
        o = 4104 + k * 64; idx, typ, a, bb = struct.unpack_from('<IIII', b, o)
        if idx == ((frm + k + 1) & 0xffffffff): out.append((typ, a, bb, struct.unpack_from('<6q', b, o + 16)))
    return out
R = recs(sys.argv[1])
dec = [t for typ, a, b, t in R if typ == 9 and t[2] > 0]
ub = sorted((t[0], a, t) for typ, a, b, t in R if typ == 10)
import bisect
ubs = [u[0] for u in ub]
rows = []
for t in dec:
    i = bisect.bisect_left(ubs, t[0])
    if i >= len(ub) or ub[i][1] != 1: continue      # decode step = one 1-token ubatch
    u = ub[i][2]
    rows.append((t[2]-t[0], t[3]-t[2], t[4]-t[3], t[5]-t[4], u[0]-t[5], u[1]-u[0], u[2]-u[1], u[3]-u[2], t[1]-u[3]))
names = ['start→batch ok(+sched_reserve)', 'memory_update', 'init_batch(slots)', 'output_reserve', '→ubatch start', 'graph reuse', 'set_inputs', 'graph_compute(issue)', '→decode end']
print(f'{len(rows)} decode steps')
for j, nm in enumerate(names):
    v = sorted(r[j] for r in rows); n = len(v)
    print(f'  {nm:32s} p10 {v[n//10]:5d} med {v[n//2]:5d} p90 {v[n*9//10]:5d} us')
