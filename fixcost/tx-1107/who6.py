# who ran on the RX-vector CPU (tracked threads) during each receiver-late stall: drun of every tracked thread bound to it
import bisect, collections, sys
sys.path.insert(0, sys.argv[4])
def load(path):
    comm, tcpu, S = {}, {}, collections.defaultdict(list)
    for line in open(path):
        p = line.split()
        if p[0] == "S": S[int(p[2])].append((int(p[1]), int(p[3]), int(p[4])))
        elif p[0] == "T": comm[int(p[2])] = p[4]; tcpu[int(p[2])] = int(p[3])
    return comm, tcpu, S
nodes = {"A": load(sys.argv[2]), "B": load(sys.argv[3])}
tot = collections.Counter(); n = 0
for line in open(sys.argv[1]):
    p = line.split()
    if p[0] != "stall": continue
    d = {p[i]: float(p[i + 1]) for i in range(2, len(p) - 1, 2)}
    if d["link"] < 2000: continue
    W = "A" if p[1] == "w0" else "B"
    la = d["t"] + d["wait"]; pa = la - d["link"]
    off = d["off"] if W == "B" else 0
    t0, t1 = pa + off, la + off + 600
    comm, tcpu, S = nodes[W]
    n += 1
    for tid, ev in S.items():
        if tcpu.get(tid) != 6: continue
        r = sum(x[1] for x in ev if t0 <= x[0] <= t1)
        if r: tot[comm[tid]] += r
print(f"{n} stalls >= 2 ms; run time of tracked CPU-6 threads in their windows (us, total):")
for k, v in tot.most_common(): print(f"  {k}: {v} ({v/n:.0f}/stall)")
