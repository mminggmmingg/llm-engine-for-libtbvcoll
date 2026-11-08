# 서버 기록 링(a.ring/b.ring)에서 단계 끝: 마지막 AR 의 상대 부분합 도착(PROXY landed) → ARGMAX_ROWS 명령 받음·끝. python3 -I sring.py <세션> [a|b]
import struct, sys, bisect, statistics as st
HDR, REC = 4096, 64
d = sys.argv[1]; side = sys.argv[2] if len(sys.argv) > 2 else "a"
b = open(f"{d}/{side}.ring", "rb").read()
frm = struct.unpack_from("<Q", b, HDR)[0]
cmds, prox = [], []
for k in range((len(b) - HDR - 8) // REC):
    o = HDR + 8 + k * REC
    idx, typ, a, bb = struct.unpack_from("<IIII", b, o)
    if idx != ((frm + k + 1) & 0xffffffff):
        continue
    t = struct.unpack_from("<6q", b, o + 16)
    if typ == 1:
        cmds.append((t[1], t[2], t[0], a))       # start, end, wait start, cmd
    elif typ == 12:
        prox.append((t[2], t[0], t[1], a))       # landed, flag seen, posted, seq
cmds.sort(); prox.sort()
pl = [p[0] for p in prox]
NAMES = {10: "GRAPH_COMPUTE", 16: "GRAPH_RECOMPUTE", 21: "COMM_ALLREDUCE", 24: "ARGMAX_ROWS", 6: "SET_TENSOR", 8: "GET_TENSOR"}
rows = []
for i, (s, e, w, c) in enumerate(cmds):
    if c != 24:
        continue
    j = bisect.bisect_left(pl, e) - 1
    if j < 0:
        continue
    landed, seen = prox[j][0], prox[j][1]
    if e - landed > 20000:   # not a decode step
        continue
    # the next GRAPH_RECOMPUTE after this argmax = next step's first launch
    nxt = next((x for x in cmds[i + 1:i + 60] if x[3] in (10, 16)), None)
    rows.append((s - landed, e - landed, e - s, (nxt[0] - e) if nxt else None, landed - seen))
print(f"{side}: {len(rows)} decode steps with ARGMAX_ROWS")
for nm, k in [("argmax command received - last AR landed", 0), ("argmax reply sent - last AR landed", 1), ("argmax command start->end", 2),
              ("argmax end -> next step's first GRAPH_RECOMPUTE received", 3), ("last AR: flag seen -> landed", 4)]:
    v = sorted(r[k] for r in rows if r[k] is not None)
    print(f"  {nm:58s} p10 {v[len(v)//10]:8.0f}  med {v[len(v)//2]:8.0f}  p90 {v[9*len(v)//10]:8.0f} us")
