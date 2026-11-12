# mtpcycle.py 를 깊이별로(ctx_bench 감시기 세션): client.ring 의 decode 단계(토큰 ≤ 8)를 2 s 넘는 틈으로 묶어(깊이마다) 검증형(서버 명령 나감)·클라이언트만(초안) 단계의
#   시작→다음 decode 중앙값·합.  mtpdepth.py <세션>/client.ring
import sys, struct, bisect
from statistics import median
b = open(sys.argv[1], 'rb').read(); frm, = struct.unpack_from('<Q', b, 4096); recs = []
for k in range((len(b) - 4104) // 64):
    o = 4104 + k * 64; idx, typ, a, bb = struct.unpack_from('<IIII', b, o)
    if idx != ((frm + k + 1) & 0xffffffff): continue
    recs.append((typ, a, bb, struct.unpack_from('<6q', b, o + 16)))
DECODE, UBATCH, CCMD = 9, 10, 7
decs = sorted([r for r in recs if r[0] == DECODE], key=lambda r: r[3][0])
ubs = sorted([r for r in recs if r[0] == UBATCH], key=lambda r: r[3][0]); ub_t = [u[3][0] for u in ubs]
cm_t = sorted(r[3][0] for r in recs if r[0] == CCMD)
rows = []
for k, d in enumerate(decs):
    t0 = d[3][0]; tn = decs[k+1][3][0] if k+1 < len(decs) else d[3][1]
    i = bisect.bisect_left(ub_t, t0); ntok = ubs[i][1] if i < len(ubs) and ub_t[i] < tn else -1
    ncmd = bisect.bisect_left(cm_t, tn) - bisect.bisect_left(cm_t, t0)
    rows.append((t0, tn, ntok, ncmd))
groups, cur = [], []
for r in [x for x in rows if 0 < x[2] <= 8]:
    if cur and r[0] - cur[-1][0] > 2e6: groups.append(cur); cur = []
    cur.append(r)
groups.append(cur)
for g in groups:
    dec = [r for r in g if 0 < r[2] <= 8]
    if len(dec) < 30: print(f"group n={len(g)} (skipped, decode rows {len(dec)})"); continue
    v = [(r[1]-r[0])/1e3 for r in dec if r[3] > 0 and r[1]-r[0] < 400e3]; d = [(r[1]-r[0])/1e3 for r in dec if r[3] == 0 and r[1]-r[0] < 400e3]
    vb = {}
    for r in dec:
        if r[3] > 0: vb.setdefault(r[2], []).append((r[1]-r[0])/1e3)
    span = (dec[-1][1]-dec[0][0])/1e3
    print(f"group decode rows {len(dec)} span {span:.0f} ms: verify-type {len(v)} med {median(v):.1f} ms sum {sum(v):.0f} | client-only {len(d)} med {median(d):.2f} ms sum {sum(d):.0f} | by ubatch tokens: " + ', '.join(f'{t}:{len(x)}x{median(x):.1f}' for t, x in sorted(vb.items())))
