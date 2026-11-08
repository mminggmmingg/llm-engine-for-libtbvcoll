# 클라이언트 기록 링(client.ring)에서 decode 단계 경계를 풀어 보기: python3 -I cring.py <세션 폴더> [단계 수=6] [건너뛸 단계=200]
# llama_decode 시작부터 각 서버의 첫 GRAPH_COMPUTE/RECOMPUTE 까지 클라이언트 기록(UBATCH 단계 시각, 보낸 명령)을 시작 기준 us 로 찍는다.
import struct, sys, collections
HDR, REC = 4096, 64
NAMES = ["ALLOC_BUFFER", "GET_ALIGNMENT", "GET_MAX_SIZE", "BUFFER_GET_BASE", "FREE_BUFFER", "BUFFER_CLEAR", "SET_TENSOR",
    "SET_TENSOR_HASH", "GET_TENSOR", "COPY_TENSOR", "GRAPH_COMPUTE", "GET_DEVICE_MEMORY", "INIT_TENSOR", "GET_ALLOC_SIZE",
    "HELLO", "DEVICE_COUNT", "GRAPH_RECOMPUTE", "MEMSET_TENSOR", "SET_TENSOR_2D", "GET_TENSOR_2D", "COMM_INIT",
    "COMM_ALLREDUCE", "COMM_FREE", "NONE", "ARGMAX_ROWS"]
d = sys.argv[1]; nshow = int(sys.argv[2]) if len(sys.argv) > 2 else 6; skip = int(sys.argv[3]) if len(sys.argv) > 3 else 200
b = open(d + "/client.ring", "rb").read()
assert b[:8] == b"GGRPCTR1"
cap, count = struct.unpack_from("<QQ", b, 16)
recs = []
# saved rings (runs/watch/<session>/, save_slice): header, u64 index of the first record, then the records back to back
frm = struct.unpack_from("<Q", b, HDR)[0]
for k in range((len(b) - HDR - 8) // REC):
    o = HDR + 8 + k * REC
    idx, typ, a, bb = struct.unpack_from("<IIII", b, o)
    if idx != ((frm + k + 1) & 0xffffffff):
        continue
    t = struct.unpack_from("<6q", b, o + 16)
    recs.append((typ, a, bb, t))
ep = {}
for typ, a, bb, t in recs:
    if typ == 8:
        ep[a] = struct.pack("<6q", *t).split(b"\0")[0].decode(errors="replace")
dec = sorted((t[0], t[1]) for typ, a, bb, t in recs if typ == 9)
ub = sorted((t[0], t[1], t[2], t[3], a, bb) for typ, a, bb, t in recs if typ == 10)
cc = sorted((t[0], t[1], t[2], a, bb) for typ, a, bb, t in recs if typ == 7)
print("endpoints", ep, "decodes", len(dec), "ccmds", len(cc))
import bisect
cq = [x[0] for x in cc]
# decode steps: decode calls whose ubatch has 1 token
steps = []
for s, e in dec:
    j = bisect.bisect_left([u[0] for u in ub], s)
    if j < len(ub) and ub[j][0] <= e and ub[j][4] == 1:
        steps.append((s, e, ub[j]))
print("1-token decode steps", len(steps))
agg = collections.defaultdict(list)
for k, (s, e, u) in enumerate(steps[skip:skip + 400]):
    i = bisect.bisect_left(cq, s)
    first = {}
    lines = []
    while i < len(cc) and cc[i][0] < e and len(first) < len(ep):
        q, st, dn, cmd, epi = cc[i]
        nm = NAMES[cmd] if cmd < len(NAMES) else str(cmd)
        lines.append(f"   +{q - s:7.0f} send +{st - s:7.0f} done +{dn - s:7.0f}  {nm:16s} ep{epi} {ep.get(epi, '')}")
        agg[(len(first), nm, epi)].append((q - s, st - q, dn - st))
        if cmd in (10, 16) and epi not in first:
            first[epi] = q - s
        i += 1
    if k < nshow:
        print(f"step {skip + k}: decode {e - s:.0f} us, ubatch prep +{u[1] - s:.0f} inputs +{u[2] - s:.0f} launched +{u[3] - s:.0f} reused={u[5]}")
        print("\n".join(lines))
print("\n== before first launch per endpoint: (order, command, ep) n, median queued-at, median queue->send, median send->done (us)")
for key in sorted(agg, key=lambda k: sorted(agg[k])[len(agg[k]) // 2][0]):
    v = agg[key]
    m = lambda j: sorted(x[j] for x in v)[len(v) // 2]
    print(f"  {key}: n={len(v)} at {m(0):7.0f}  q->s {m(1):6.0f}  s->d {m(2):6.0f}")
