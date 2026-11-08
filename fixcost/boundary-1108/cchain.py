# 클라이언트 기록 링으로 토큰 경계 사슬(중앙 µs, 마지막 ARGMAX_ROWS 응답 받은 때 = 0): python3 -I cchain.py <세션>
import struct, sys, bisect, statistics as st
HDR, REC = 4096, 64
d = sys.argv[1]
b = open(d + "/client.ring", "rb").read()
frm = struct.unpack_from("<Q", b, HDR)[0]
recs = []
for k in range((len(b) - HDR - 8) // REC):
    o = HDR + 8 + k * REC
    idx, typ, a, bb = struct.unpack_from("<IIII", b, o)
    if idx != ((frm + k + 1) & 0xffffffff):
        continue
    recs.append((typ, a, bb, struct.unpack_from("<6q", b, o + 16)))
ep = {}
for typ, a, bb, t in recs:
    if typ == 8:
        ep[a] = struct.pack("<6q", *t).split(b"\0")[0].decode(errors="replace")
dec = sorted((t[0], t[1]) for typ, a, bb, t in recs if typ == 9)
ub = sorted((t[0], t[1], t[2], t[3], a) for typ, a, bb, t in recs if typ == 10)
cc = sorted((t[0], t[1], t[2], a, bb) for typ, a, bb, t in recs if typ == 7)
arg = sorted(x for x in cc if x[3] == 24)
ubs = [u[0] for u in ub]; ccq = [x[0] for x in cc]
rows = []
for s, e in dec:
    j = bisect.bisect_left(ubs, s)
    if j >= len(ub) or ub[j][0] > e or ub[j][4] != 1:
        continue
    u = ub[j]
    # last ARGMAX_ROWS reply (done) before this decode
    i = bisect.bisect_left([x[2] for x in arg], s) - 1
    if i < 1:
        continue
    t0 = max(arg[i][2], arg[i - 1][2]) if abs(arg[i][2] - arg[i - 1][2]) < 2000 else arg[i][2]
    if s - t0 > 3000:
        continue
    k = bisect.bisect_left(ccq, s)
    first_set = None; first_gr = {}; sent_gr = {}
    while k < len(cc) and cc[k][0] < e and len(sent_gr) < 2:
        q, sn, dn, cmd, epi = cc[k]
        h = "A" if ep.get(epi, "").startswith("127.") else "B"
        if cmd == 6 and first_set is None:
            first_set = q
        if cmd in (10, 16) and h not in first_gr:
            first_gr[h] = q; sent_gr[h] = sn
        k += 1
    if len(sent_gr) < 2 or first_set is None:
        continue
    rows.append([s - t0, u[1] - t0, u[2] - t0, u[3] - t0, first_set - t0, first_gr["B"] - t0, sent_gr["B"] - t0, first_gr["A"] - t0, sent_gr["A"] - t0])
names = ["llama_decode start", "ubatch graph ready", "ubatch inputs set", "ubatch compute returned", "first SET_TENSOR queued",
         "B first GRAPH_RECOMPUTE queued", "B first GRAPH_RECOMPUTE sent", "A first GRAPH_RECOMPUTE queued", "A first GRAPH_RECOMPUTE sent"]
print(f"{d}: {len(rows)} decode steps (0 = last ARGMAX_ROWS reply at the client)")
for n, c in enumerate(names):
    v = sorted(r[n] for r in rows)
    print(f"  {c:34s} p10 {v[len(v)//10]:6.0f}  med {v[len(v)//2]:6.0f}  p90 {v[9*len(v)//10]:6.0f}")
