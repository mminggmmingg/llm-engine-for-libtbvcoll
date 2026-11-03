# 단계 시작 사슬: llama_decode 시작 → 클라이언트가 단계 첫 명령들을 보냄(CCMD) → 서버 첫 GRAPH 명령(CMD) — firstcmd.py <세션 폴더>
import sys, struct, bisect, collections, statistics as st
def recs(p):
    b = open(p, 'rb').read(); frm = struct.unpack_from('<Q', b, 4096)[0]; out = []
    for k in range((len(b) - 4104) // 64):
        o = 4104 + k * 64; idx, typ, a, bb = struct.unpack_from('<IIII', b, o)
        if idx == ((frm + k + 1) & 0xffffffff): out.append((typ, a, bb, struct.unpack_from('<6q', b, o + 16)))
    return out
d = sys.argv[1]
C = recs(d + '/client.ring'); A = recs(d + '/a.ring')
NAMES = ["ALLOC_BUFFER","GET_ALIGNMENT","GET_MAX_SIZE","BUFFER_GET_BASE","FREE_BUFFER","BUFFER_CLEAR","SET_TENSOR","SET_TENSOR_HASH","GET_TENSOR","COPY_TENSOR","GRAPH_COMPUTE","GET_DEVICE_MEMORY","INIT_TENSOR","GET_ALLOC_SIZE","HELLO","DEVICE_COUNT","GRAPH_RECOMPUTE","MEMSET_TENSOR","SET_TENSOR_2D","GET_TENSOR_2D","COMM_INIT","COMM_ALLREDUCE","COMM_FREE"]
ep = {}
for typ, a, b, t in C:
    if typ == 8:
        bs = b''.join(struct.pack('<q', v) for v in t); ep[a] = bs.split(b'\0')[0].decode()
dec = sorted(t[0] for typ, a, b, t in C if typ == 9 and t[2] > 0)
cc = sorted((t[1], a, b, t) for typ, a, b, t in C if typ == 7)   # send start
ccs = [x[0] for x in cc]
seqs = collections.defaultdict(list)
for t0 in dec[50:-5]:
    i = bisect.bisect_left(ccs, t0)
    for k in range(i, min(i + int(sys.argv[2]) if len(sys.argv) > 2 else i + 12, len(cc))):
        s, a, b, t = cc[k]
        seqs[k - i].append((NAMES[a] if a < len(NAMES) else a, ep.get(b, b), t[0] - t0, t[1] - t0, t[2] - t0))
print('client: first commands of each decode step (us from llama_decode start: queued / send start / done)')
for k in sorted(seqs):
    v = seqs[k]; name = collections.Counter((x[0], x[1]) for x in v).most_common(1)[0][0]
    print(f'  #{k:2d} {name[0]:16s} → {name[1]:20s} queued {st.median(x[2] for x in v):6.0f}  send {st.median(x[3] for x in v):6.0f}  done {st.median(x[4] for x in v):6.0f}')
