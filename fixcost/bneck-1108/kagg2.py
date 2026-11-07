# decode kernel time per token by kernel (A server, prof2node): kagg2.py <kernel_trace.csv> [tokens marker kernel]
import csv, sys, collections
K = sorted((int(r['Start_Timestamp']), int(r['End_Timestamp']), r['Kernel_Name'], int(r['Grid_Size_X']), int(r['Workgroup_Size_X'])) for r in csv.DictReader(open(sys.argv[1])))
toks=[]; cur=[]
for k in K:
    if cur and k[0]-cur[-1][1] > 1_000_000: toks.append(cur); cur=[]
    cur.append(k)
toks.append(cur)
big = max(toks, key=len)
def short(n):
    n = n.replace('void ', '').split('(')[0]
    return n.split('<')[0] + ('<' + n.split('<')[1].split(',')[0][:30] + '>' if '<' in n else '')
ntok = sum(1 for k in big if short(k[2]) == 'dsv4_hc_post_f32<false>')
span = (big[-1][1] - big[0][0]) / 1e6
busy = sum(k[1] - k[0] for k in big) / 1e6
print(f"decode tokens {ntok}, span {span/ntok:.2f} ms/token, kernel busy {busy/ntok:.2f} ms/token, kernels {len(big)/ntok:.0f}/token")
t = collections.defaultdict(float); n = collections.Counter()
for k in big:
    t[short(k[2])] += (k[1]-k[0])/1e3; n[short(k[2])] += 1
rows = sorted(((t[x]/ntok, n[x]/ntok, x) for x in t), reverse=True)
cum = 0; tot = sum(r[0] for r in rows)
print(f"{'us/tok':>7} {'calls':>6} {'us/call':>8} {'cum%':>5}  kernel")
for us, c, name in rows[:32]:
    cum += us
    print(f"{us:7.0f} {c:6.1f} {us/c:8.1f} {100*cum/tot:5.1f}  {name}")
