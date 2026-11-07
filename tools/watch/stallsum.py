#!/usr/bin/env python3
"""Compare inferwatch sessions in one table: stallsum.py <label>=<session dir> ...

Per session: the watcher's decode tok/s and ms per step, AR latency per direction (median / p99), the waits over 1 ms
(ms per step, and how many the receipt puts on the link and on the peer's compute), and the link delays over 1 ms by
size (1-2.5 / 2.5-3.5 / 3.5-7 / 7-12 / >12 ms, the clusters of fixcost/lnk-1107). The per-wait list comes from
`inferwatch report` with INFERWATCH_STALLS=1, kept as <session>/stalls.txt (made once).
"""
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
BIN = os.path.join(HERE, "target", "release", "inferwatch")
BINS = [(1000, 2500), (2500, 3500), (3500, 7000), (7000, 12000), (12000, float("inf"))]


def stalls(sess):
    path = os.path.join(sess, "stalls.txt")
    if not os.path.exists(path):
        with open(path, "w") as f:
            subprocess.run([BIN, "report", sess], stdout=subprocess.DEVNULL, stderr=f, check=False,
                           env=dict(os.environ, INFERWATCH_STALLS="1"))
    rows = []
    for line in open(path):
        p = line.split()
        if p and p[0] == "stall":
            rows.append({p[i]: float(p[i + 1]) for i in range(2, len(p) - 1, 2)})
    return rows


def receipt(sess):
    text = open(os.path.join(sess, "receipt.md")).read()
    m = re.search(r"단계당 ([0-9.]+) ms · \*\*([0-9.]+) tok/s\*\*", text)
    steps = re.search(r"decode 단계 (\d+)개", text)
    lat = {}
    for d in ("A → B", "B → A"):
        r = re.search(r"^\| " + d + r" \|[^|]*\|[^|]*\| ([^|]+)\|", text, re.M)
        if r:
            q = [x.strip() for x in r.group(1).split("/")]
            lat[d] = f"{q[1]} / {q[3]}"
    cause = {}
    for key, pat in (("link", r"^\| 링크 [^|]*\| (\d+) \|"), ("peer", r"^\| 상대 GPU 가 늦게 끝냄[^|]*\| (\d+) \|")):
        r = re.search(pat, text, re.M)
        cause[key] = r.group(1) if r else "-"
    return (float(m.group(1)) if m else float("nan"), float(m.group(2)) if m else float("nan"),
            int(steps.group(1)) if steps else 0, lat, cause)


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    print("| 설정 | 감시기 tok/s | ms/단계 | AR 지연 A→B 중앙 / p99 µs | B→A | 1 ms 넘는 기다림 ms/단계 | 그중 링크 / 상대 계산 (번) |"
          " 링크 늦음 1–2.5 / 2.5–3.5 / 3.5–7 / 7–12 / >12 ms (번) | 세션 |")
    print("|---|---:|---:|---|---|---:|---|---|---|")
    for arg in sys.argv[1:]:
        label, sess = arg.split("=", 1) if "=" in arg else (os.path.basename(arg.rstrip("/")), arg)
        ms, tps, nsteps, lat, cause = receipt(sess)
        rows = stalls(sess)
        wait = sum(r["wait"] for r in rows) / max(nsteps, 1) / 1000
        bins = [sum(lo <= r["link"] < hi for r in rows) for lo, hi in BINS]
        print(f"| {label} | {tps:.1f} | {ms:.2f} | {lat.get('A → B', '-')} | {lat.get('B → A', '-')} | {wait:.2f} | "
              f"{cause['link']} / {cause['peer']} | {' / '.join(map(str, bins))} | {os.path.basename(sess.rstrip('/'))} |")


if __name__ == "__main__":
    main()
