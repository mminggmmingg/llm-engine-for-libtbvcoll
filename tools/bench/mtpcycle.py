# MTP 한 주기 나누기: inferwatch 가 저장한 client.ring(runs/watch/<시각>/) 의 DECODE/UBATCH/SYNC/CCMD 기록으로 검증 단계(서버로 명령이 나감)와 초안 단계(클라이언트 GPU)를 가른다. 시각 단위 us
import sys, struct, statistics as st
from collections import Counter
b = open(sys.argv[1], 'rb').read()
assert b[0:8] == b'GGRPCTR1'
# inferwatch 가 저장한 조각: 머리 4096 B + 첫 기록 번호(u64) + 이어진 기록들
frm, = struct.unpack_from('<Q', b, 4096)
recs = []
for k in range((len(b) - 4104) // 64):
    o = 4104 + k * 64
    idx, typ, a, bb = struct.unpack_from('<IIII', b, o)
    if idx != ((frm + k + 1) & 0xffffffff):
        continue
    t = struct.unpack_from('<6q', b, o + 16)
    recs.append((typ, a, bb, t))
DECODE, UBATCH, SYNC, CCMD = 9, 10, 11, 7
# decode 마다: 시작·끝, ubatch 토큰, 그 decode 시작부터 다음 decode 시작까지의 CCMD 수, 그 사이 SYNC 끝
decs = [r for r in recs if r[0] == DECODE]
decs.sort(key=lambda r: r[3][0])
ubs = sorted([r for r in recs if r[0] == UBATCH], key=lambda r: r[3][0])
syncs = sorted([r for r in recs if r[0] == SYNC], key=lambda r: r[3][0])
cmds = sorted([r for r in recs if r[0] == CCMD], key=lambda r: r[3][0])
import bisect
ub_t = [u[3][0] for u in ubs]; sy_t = [s[3][0] for s in syncs]; cm_t = [c[3][0] for c in cmds]
rows = []
for k, d in enumerate(decs):
    t0, t1 = d[3][0], d[3][1]
    tn = decs[k + 1][3][0] if k + 1 < len(decs) else t1 + 10**9
    i = bisect.bisect_left(ub_t, t0); ntok = ubs[i][1] if i < len(ubs) and ub_t[i] < tn else -1
    j0 = bisect.bisect_left(cm_t, t0); j1 = bisect.bisect_left(cm_t, tn); ncmd = j1 - j0
    s0 = bisect.bisect_left(sy_t, t0); s1 = bisect.bisect_left(sy_t, tn)
    send = max([syncs[s][3][1] for s in range(s0, s1)], default=t1)
    rows.append((t0, t1, tn, ntok, ncmd, send))
# decode 단계만(prefill 제외: 토큰 > 8)
rows = [r for r in rows if 0 < r[3] <= 8]
ver = [r for r in rows if r[4] > 0]; dra = [r for r in rows if r[4] == 0]
print(f"decode 단계 {len(rows)}: 서버로 명령이 나간 단계 {len(ver)}, 클라이언트만 {len(dra)}")
span = (max(r[3][1] for r in recs if r[0]==DECODE) - min(r[3][0] for r in recs if r[0]==DECODE))
print(f"DECODE 기록 처음→끝 {span/1e3:.0f} ms (기록 길이 38.58 s 와 비교)")
q = lambda xs, p: sorted(xs)[int(p*(len(xs)-1))] if xs else float('nan')
for name, rs in (("검증", ver), ("초안", dra)):
    a = [(r[5]-r[0])/1e3 for r in rs]; n = [(r[2]-r[0])/1e3 for r in rs if (r[2]-r[0]) < 200e3]
    print(f"{name}: 시작→결과 ms 중앙 {q(a,.5):.2f} p10 {q(a,.1):.2f} p90 {q(a,.9):.2f} | 시작→다음 decode(200 ms 미만) 중앙 {q(n,.5):.2f} 합 {sum(n)/1e3:.2f} s ({len(n)}개)")
from collections import Counter
h = Counter(int((r[2]-r[0])/1e3/5)*5 for r in ver if (r[2]-r[0]) < 200e3); print("검증 시작→다음 decode 분포(5 ms 칸):", sorted(h.items()))
h = Counter(int((r[5]-r[0])/1e3/5)*5 for r in ver); print("검증 시작→결과 분포:", sorted(h.items())[:12])
seq = ''.join('V' if r[4] > 0 else 'd' for r in rows[:80]); print("순서:", seq)
