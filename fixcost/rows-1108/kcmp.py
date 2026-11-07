# per-token kernel time by (kernel, grid) in the last W ms of an A-server trace (prof2node.sh): kcmp.py <csv> [W ms=1200]
# token = one output-layer matmul (grid 3973120). Same grouping as fixcost/bneck-1108/kgroups-A.txt.
import csv, sys, collections
f = sys.argv[1]; W = float(sys.argv[2]) if len(sys.argv) > 2 else 1200.0
K = sorted((int(r['Start_Timestamp']), int(r['End_Timestamp']), r['Kernel_Name'], int(r['Grid_Size_X']) * int(r['Grid_Size_Y']) * int(r['Grid_Size_Z']), int(r['Workgroup_Size_X']) * int(r['Workgroup_Size_Y']))
           for r in csv.DictReader(open(f)))
end = K[-1][1]; K = [k for k in K if k[0] >= end - W * 1e6]
def short(n):
    n = n.replace('void ', '').replace('(ggml_type)', 't').split('(')[0]
    return n
ntok = sum(1 for k in K if k[3] == 3973120)
t = collections.defaultdict(float); n = collections.Counter()
for k in K:
    key = (short(k[2]), k[3], k[4]); t[key] += (k[1] - k[0]) / 1e3; n[key] += 1
print(f"window {W:.0f} ms, tokens {ntok}, per token {W/ntok:.2f} ms, kernel time/token {sum(t.values())/ntok/1e3:.2f} ms, kernels/token {len(K)/ntok:.0f}")
for key in sorted(t, key=lambda x: -t[x])[:20]:
    print(f"{t[key]/ntok:8.0f} us/tok  n/tok {n[key]/ntok:6.1f}  avg {t[key]/n[key]:7.1f} us  grid {key[1]:8d} wg {key[2]:5d}  {key[0]}")
