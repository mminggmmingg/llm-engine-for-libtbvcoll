# prof2node.sh 커널 기록 두 개(또는 하나)를 토큰당으로 비교: 커널 이름(앞 60자)·격자·블록 크기마다 토큰당 개수와 평균 µs.
#   argv: run_dir [run_dir2]  — 토큰 수 = gated_delta_net 커널 수 / 36(GDN 층 36개). 프로파일러 아래 값이라 절대값보다 차이를 볼 것.
import csv, sys, collections
def load(d):
    c = collections.Counter(); t = collections.Counter()
    for r in csv.DictReader(open(f'{d}/a_kernel_trace.csv')):
        k = r['Kernel_Name'].replace('void ', '').split('(')[0][:60] + f" g{r['Grid_Size_X']}x{r['Grid_Size_Y']} w{r['Workgroup_Size_X']}"
        c[k] += 1; t[k] += int(r['End_Timestamp']) - int(r['Start_Timestamp'])
    ntok = sum(v for k, v in c.items() if k.startswith('gated_delta_net_cuda')) / 36
    return ntok, c, t
R = [load(d) for d in sys.argv[1:]]
for d, (ntok, c, t) in zip(sys.argv[1:], R):
    print(f'{d}: tokens {ntok:.1f} kernels/token {sum(c.values())/ntok:.0f} kernel us/token {sum(t.values())/ntok/1e3:.0f}')
if len(R) == 1:
    ntok, c, t = R[0]
    for k, v in sorted(c.items(), key=lambda kv: -kv[1]):
        if v / ntok >= 3:
            print(f'{v/ntok:7.1f} /tok {t[k]/v/1e3:7.1f} us  {k}')
else:
    (na, ca, ta), (nb, cb, tb) = R
    rows = []
    for k in set(ca) | set(cb):
        a, b = ca[k]/na, cb[k]/nb
        ua, ub = ta[k]/na/1e3, tb[k]/nb/1e3
        if abs(a - b) > 0.5 or abs(ua - ub) > 15:
            rows.append((ub - ua, k, a, b, ua, ub))
    for r in sorted(rows):
        print(f'{r[2]:6.1f} -> {r[3]:6.1f} /tok  {r[4]:8.1f} -> {r[5]:8.1f} us/tok  {r[1]}')
