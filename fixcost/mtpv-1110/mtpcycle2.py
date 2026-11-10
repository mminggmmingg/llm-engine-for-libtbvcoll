# MTP 한 주기 나누기(단계 사이까지, mtpcycle.py 확장): inferwatch 가 저장한 client.ring(runs/watch/<시각>/) 의 DECODE/UBATCH/SYNC/CCMD 기록으로 검증 단계(서버로 명령이 나감)와 초안 단계(클라이언트 GPU)를 가른다. 시각 단위 us
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
# decode 단계만(prefill 제외: 토큰 > 8). 단계마다: 호출(t1-t0), 결과 기다림(send-t1, 음수면 0), 다음 decode 까지 클라이언트(tn-max(t1,send))
rows = [r for r in rows if 0 < r[3] <= 8]
q = lambda xs, p: sorted(xs)[int(p*(len(xs)-1))] if xs else float('nan')
def role(r):
    return ('V%d' % r[3]) if r[4] > 0 else ('d%d' % r[3])
from collections import defaultdict
parts = defaultdict(lambda: ([], [], []))
for r in rows:
    if r[2] - r[0] > 200e3:
        continue  # 프롬프트 사이
    call = (r[1] - r[0])/1e3; wait = max(0, r[5] - r[1])/1e3; after = (r[2] - max(r[1], r[5]))/1e3
    p = parts[role(r)]; p[0].append(call); p[1].append(wait); p[2].append(after)
n_cyc = sum(1 for r in rows if r[4] > 0 and r[3] > 1 and r[2] - r[0] < 200e3)
print(f"단계 종류(V=서버로 명령, d=클라이언트만, 숫자=토큰): 주기(여러 토큰 검증) {n_cyc}개")
print("| 단계 | 개수 | 주기당 개수 | 호출 ms 중앙 | 결과 기다림 ms 중앙 | 다음 decode 까지 클라이언트 ms 중앙 | 주기당 합 ms (호출+기다림+그 뒤) |")
print("|---|---:|---:|---:|---:|---:|---:|")
tot = 0
for k in sorted(parts):
    c, w, a = parts[k]
    s = (sum(c) + sum(w) + sum(a)) / n_cyc
    tot += s
    print(f"| {k} | {len(c)} | {len(c)/n_cyc:.2f} | {q(c,.5):.2f} | {q(w,.5):.2f} | {q(a,.5):.2f} | {s:.2f} |")
print(f"| 합 | | | | | | {tot:.2f} |")
seq = ''.join(role(r) + ' ' for r in rows[:40]); print("순서:", seq)
