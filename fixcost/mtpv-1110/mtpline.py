# MTP 한 주기 나누기(단계별 시각 줄, mtpcycle.py 확장): mtpline.py <client.ring> [시작 단계=200] [개수=30]: inferwatch 가 저장한 client.ring(runs/watch/<시각>/) 의 DECODE/UBATCH/SYNC/CCMD 기록으로 검증 단계(서버로 명령이 나감)와 초안 단계(클라이언트 GPU)를 가른다. 시각 단위 us
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
rows = [r for r in rows if 0 < r[3] <= 8]
s0 = int(sys.argv[2]) if len(sys.argv) > 2 else 200; nn = int(sys.argv[3]) if len(sys.argv) > 3 else 30
base = rows[s0][0]
print("단계 | 시작 ms | 호출 ms | 결과(마지막 SYNC 끝)까지 ms | 다음 decode 까지 ms | 서버 명령 수")
for r in rows[s0:s0 + nn]:
    print(f"{'V' if r[4] else 'd'}{r[3]} | {(r[0]-base)/1e3:8.2f} | {(r[1]-r[0])/1e3:6.2f} | {(r[5]-r[0])/1e3:7.2f} | {(r[2]-r[0])/1e3:7.2f} | {r[4]}")
