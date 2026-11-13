# Throughput by final output tokens next to the bytes behind it (2026-11-14, from a reviewer's suggestion):
#   outsum.py <label>=<run dir>[,<dram json without -a/-b.json>] ...
# Per run: output t/s (what the user sees: spec_bench TOTAL, or ctx_bench tg128 per depth), the weight-based effective GB/s per node
# (output t/s x the weights a plain decode reads per token per node, WEIGHT_GB, default 2.83 = H5 TP2 from tools/bytes_per_token.py),
# and, when the run has inferwatch DRAM data, the measured DRAM GB/s during decode and DRAM GB per *output* token (MTP verifies more
# tokens than it outputs: the watcher's per-processed-token bytes x processed / output tokens).
# The effective figure can exceed the hardware's bandwidth with MTP — that is the point: it is the plain-decode work each output
# token stands for; the DRAM columns are what the memory really did.
import json, os, re, sys
W = float(os.environ.get('WEIGHT_GB', '2.83'))
print('| run | output t/s | weight-based GB/s per node (x %.2f GB) | DRAM GB/s A / B | DRAM GB per output token A / B |' % W)
print('|---|---:|---:|---|---|')
for a in sys.argv[1:]:
    label, rest = a.split('=', 1)
    parts = rest.split(',')
    d = parts[0]
    dram = parts[1] if len(parts) > 1 else ''
    rows = []
    bt = os.path.join(d, 'bench.txt')
    total = None
    if os.path.exists(bt):
        m = re.search(r'TOTAL tokens (\d+), decode ([\d.]+) tok/s', open(bt).read())
        if m:
            total = (int(m.group(1)), float(m.group(2)))
            rows.append((label, float(m.group(2))))
    cj = os.path.join(d, 'ctx.jsonl')
    if os.path.exists(cj):
        for l in open(cj):
            r = json.loads(l)
            rows.append((f'{label} tg128 @ {r["depth"]}', r['tg_n'] / r['tg_ms'] * 1e3))
    dcols = ['', '']
    if dram:
        gbs, gbo = [], []
        for x in 'ab':
            try:
                j = json.load(open(f'{dram}-{x}.json'))
                gbs.append(str(j['gbps_during_decode']))
                if total:
                    gbo.append('%.3f' % (float(j['gb_per_token']) * float(j['decode_tokens']) / total[0]))
                else:
                    gbo.append('?')
            except Exception:
                gbs.append('—'); gbo.append('—')
        dcols = [' / '.join(gbs), ' / '.join(gbo)]
    for lab, tps in rows:
        print(f'| {lab} | {tps:.2f} | {tps * W:.1f} | {dcols[0]} | {dcols[1]} |')
