#!/usr/bin/env python3
"""Split each AR link delay over 1 ms into sender and receiver parts: txsplit.py <stalls.txt> <smp-A.txt> <smp-B.txt> [cfg]
stalls.txt: `inferwatch report` with INFERWATCH_STALLS=1 (t on A's clock, off = B - A clock there). smp-*: tbsample on each
node (CLOCK_MONOTONIC us). cfg: "A:tx=53,rx=54 B:tx=54,rx=55" — the AR device's TX / RX vectors per node (default: the two
non-control vectors of NHI c5:00.5 = usb4_rdma0, TX first, as tbv allocates its TX ring before its RX ring).
For a delay seen by waiter W (data sent by the peer P): P posted at p (P's clock), W's proxy had it at l. Per stall:
  tx_irq  = first interrupt on P's AR TX vector after p (the NHI finished reading the frame: it left P)
  rx_irq  = first interrupt on W's AR RX vector after p (moved to W's clock): the frame landed at W
and the receiver threads' runqueue waits between p and l (W's kworkers on the RX vector CPU, W's rpc-server threads).
The sampler period (0.5 ms) is the resolution of tx_irq / rx_irq.
"""
import bisect, collections, sys

def load(path):
    irq = collections.defaultdict(list)   # irq -> [t]
    vcpu, comm, tcpu = {}, {}, {}
    S = collections.defaultdict(list)     # tid -> [(t, drun, dwait)]
    for line in open(path):
        p = line.split()
        if not p:
            continue
        if p[0] == "I":
            irq[int(p[2])].append(int(p[1]))
        elif p[0] == "S":
            S[int(p[2])].append((int(p[1]), int(p[3]), int(p[4])))
        elif p[0] == "T":
            comm[int(p[2])] = p[4] if len(p) > 4 else "?"
            tcpu[int(p[2])] = int(p[3])
        elif p[0] == "V":
            vcpu[int(p[2])] = int(p[3])
    return irq, vcpu, comm, tcpu, S

def first_after(ts, t):
    i = bisect.bisect_left(ts, t)
    return ts[i] if i < len(ts) else None

def main():
    st_path, pa, pb = sys.argv[1:4]
    cfg = sys.argv[4] if len(sys.argv) > 4 else "A:tx=53,rx=54 B:tx=54,rx=55"
    vec = {}
    for part in cfg.split():
        n, kv = part.split(":")
        vec[n] = {k: int(v) for k, v in (x.split("=") for x in kv.split(","))}
    node = {"A": load(pa), "B": load(pb)}
    for n in "AB":
        irq, vcpu = node[n][0], node[n][1]
        print(f"{n}: vectors (irq:cpu:count) " + " ".join(f"{i}:{vcpu.get(i)}:{len(irq[i])}" for i in sorted(vcpu)) +
              f" | AR tx {vec[n]['tx']} rx {vec[n]['rx']}")
    rows = []
    for line in open(st_path):
        p = line.split()
        if not p or p[0] != "stall":
            continue
        d = {p[i]: float(p[i + 1]) for i in range(2, len(p) - 1, 2)}
        d["w"] = "A" if p[1] == "w0" else "B"
        if d["link"] >= 1000:
            rows.append(d)
    smp_t0 = {n: min(min(v) for v in node[n][0].values() if v) for n in "AB"}
    smp_t1 = {n: max(max(v) for v in node[n][0].values() if v) for n in "AB"}
    out = []
    for d in rows:
        W = d["w"]; P = "B" if W == "A" else "A"
        landed_a = d["t"] + d["wait"]
        posted_a = landed_a - d["link"]
        to = lambda n, ta: ta + (d["off"] if n == "B" else 0.0)   # A clock -> node n's clock
        p_P, p_W, l_W = to(P, posted_a), to(W, posted_a), to(W, landed_a)
        if not (smp_t0[P] <= p_P <= smp_t1[P] and smp_t0[W] <= l_W <= smp_t1[W]):
            continue
        tx = first_after(node[P][0][vec[P]["tx"]], p_P - 250)
        rx = first_after(node[W][0][vec[W]["rx"]], p_W - 250)
        txd = (tx - p_P) if tx is not None else float("nan")
        rxd = (rx - p_W) if rx is not None else float("nan")
        # receiver waits in [p_W, l_W + 600]
        irq_cpu = node[W][1].get(vec[W]["rx"])
        waits = []
        for tid, ev in node[W][4].items():
            w = sum(x[2] for x in ev if p_W <= x[0] <= l_W + 600)
            if w >= 200:
                waits.append((w, tid))
        waits.sort(reverse=True)
        names = [f"{node[W][2].get(t, '?')}[{node[W][3].get(t)}]:{w}" for w, t in waits[:3]]
        out.append((d, W, txd, rxd, irq_cpu, names))
    # summary: where the delay sits
    cls = collections.Counter()
    for d, W, txd, rxd, cpu, names in out:
        link = d["link"]
        if rxd != rxd:
            c = "no rx irq"
        elif rxd >= link - 700:
            c = "frame landed late (sender / wire)"
        elif rxd <= 700:
            c = "landed on time, receiver late"
        else:
            c = "in between"
        cls[(W, c)] += 1
    print(f"link delays >= 1 ms inside the sampled window: {len(out)}")
    for k in sorted(cls):
        print(f"  waiter {k[0]}: {k[1]}: {cls[k]}")
    print("waiter link_us tx_irq_us rx_irq_us | receiver runqueue waits >=200us in the window (comm[cpu]:us)")
    for d, W, txd, rxd, cpu, names in sorted(out, key=lambda x: -x[0]["link"])[:60]:
        print(f"{W} {d['link']:6.0f} {txd:7.0f} {rxd:7.0f} | {' '.join(names)}")

main()
