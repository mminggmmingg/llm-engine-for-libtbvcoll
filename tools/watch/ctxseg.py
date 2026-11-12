# 컨텍스트 길이별 감시기 세션(ctx_bench.py, 기록 링 켠 회)의 decode 단계를 깊이(측정)별로 가르고, 깊이마다 단계 시간과 AR 사이 구간별 GPU 계산 시간(중앙값, µs).
# 대리 스레드 AR 기록(ZC=3, 기록 종류 12: a = 순번, b = 바이트, t0 = 우리 부분합 플래그 본 때, t2 = 상대 부분합 도착)에서 그 크기의 AR 만 골라 순번이 이어지는
# 묶음을 AR 수(층 48 × 2 = 96)씩 단계로 자르고, 단계 사이가 gap_s 초 넘게 비면 다른 측정(깊이)으로 본다. 구간 k 의 계산 = t0[k] − max(t2[k−1], t0[k−1]).
# 묶음의 첫 AR 이 단계의 첫 AR 이 아닐 수 있어(앞 단계 마지막 AR 부터 잘림) 구간 번호가 한 칸 밀릴 수 있다 — 끝에 k mod 8 별 합을 찍으니 깊이에 따라 커지는
# 줄(이 엔진에서는 4층마다 오는 QSA 층의 attention 구간, 1토큰 none 회는 k ≡ 7, MTP 4토큰 검증은 k ≡ 6 이었다)과 단계 경계가 든 줄을 거기서 본다.
#   ctxseg.py <세션 폴더> [AR 수=96] [gap_s=2] [단계 상한 ms=200] [AR 바이트=10240(1토큰), MTP 4토큰 검증 40960] [최소 단계 수=30]
import sys, struct, collections
from statistics import median
def load(path):
    b = open(path, 'rb').read()
    frm, = struct.unpack_from('<Q', b, 4096)
    recs = []
    for k in range((len(b) - 4104) // 64):
        o = 4104 + k * 64
        idx, typ, a, bb = struct.unpack_from('<IIII', b, o)
        if idx != ((frm + k + 1) & 0xffffffff): continue
        recs.append((typ, a, bb, struct.unpack_from('<6q', b, o + 16)))
    return recs
sess = sys.argv[1].rstrip('/'); nar = int(sys.argv[2]) if len(sys.argv) > 2 else 96
ARB = int(sys.argv[5]) if len(sys.argv) > 5 else 10240  # AR bytes: 10240 = 1 token (none), 40960 = 4-token MTP verify
MINN = int(sys.argv[6]) if len(sys.argv) > 6 else 30   # 이보다 단계가 적은 묶음(데우기 등)은 표에서 뺌
gap = float(sys.argv[3]) if len(sys.argv) > 3 else 2.0; maxstep = float(sys.argv[4]) if len(sys.argv) > 4 else 200.0
out = {}
for node in 'ab':
    px = sorted([r for r in load(f'{sess}/{node}.ring') if r[0] == 12 and r[2] == ARB], key=lambda r: r[1])
    runs, cur = [], [px[0]]
    for p in px[1:]:
        if p[1] == cur[-1][1] + 1 and p[3][0] - cur[-1][3][2] < 1_000_000:
            cur.append(p)
        else:
            runs.append(cur); cur = [p]
    runs.append(cur)
    dec = []
    for rn in runs:
        dec += [rn[i:i + nar] for i in range(0, len(rn) - nar + 1, nar)]
    dec = [s for s in dec if (s[-1][3][2] - s[0][3][0]) / 1e3 < maxstep]
    dec.sort(key=lambda s: s[0][3][0])
    phases, ph = [], [dec[0]]
    for s in dec[1:]:
        if s[0][3][0] - ph[-1][-1][3][2] > gap * 1e6:
            phases.append(ph); ph = [s]
        else:
            ph.append(s)
    phases.append(ph)
    res = []
    for ph in phases:
        comp = collections.defaultdict(list)
        for s in ph:
            for k in range(1, len(s)):
                comp[k].append(s[k][3][0] - max(s[k-1][3][2], s[k-1][3][0]))
        starts = [s[0][3][0] for s in ph]
        per = [ (starts[i+1] - starts[i]) / 1e3 for i in range(len(starts) - 1) if starts[i+1] - starts[i] < maxstep * 1e3]
        res.append(dict(n=len(ph), t0=ph[0][0][3][0] / 1e6, step=median(per) if per else None, comp={k: median(v) for k, v in comp.items()}))
    out[node] = res
for node in 'ab':
    print(node, 'phases:', [(r['n'], round(r['t0'] - out[node][0]['t0'], 1), round(r['step'], 2) if r['step'] else None) for r in out[node]])
# per position, phases side by side (node a, b)
big = [i for i, r in enumerate(out['a']) if r['n'] >= MINN]
print(f'phases used (n>={MINN}):', big)
print('pos ' + ' '.join(f'A{i:>6d}' for i in big) + ' | ' + ' '.join(f'B{i:>6d}' for i in big))
for k in range(1, nar):
    va = [out['a'][i]['comp'].get(k) for i in big]; vb = [out['b'][i]['comp'].get(k) for i in big if i < len(out['b'])]
    print(f'{k:3d} ' + ' '.join(f'{v:7.0f}' if v is not None else '      -' for v in va) + ' | ' + ' '.join(f'{v:7.0f}' if v is not None else '      -' for v in vb))
for i in big:
    sa = sum(out['a'][i]['comp'].values()); sb = sum(out['b'][i]['comp'].values()) if i < len(out['b']) else 0
    print(f'phase {i}: n={out["a"][i]["n"]} step {out["a"][i]["step"]:.2f} ms, A comp sum {sa/1e3:.2f} ms, B comp sum {sb/1e3:.2f} ms')
for node in 'ab':
    res = [[0.0] * len(big) for _ in range(8)]
    for j, i in enumerate(big):
        if i >= len(out[node]):
            continue
        for k, v in out[node][i]['comp'].items():
            res[k % 8][j] += v
    print(f'{node} k mod 8 sums (ms, phases {big}): ' + '  '.join(f'r{r}:' + '/'.join(f'{x / 1e3:.1f}' for x in res[r]) for r in range(8)))
