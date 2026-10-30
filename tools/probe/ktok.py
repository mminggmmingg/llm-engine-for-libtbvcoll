# rocprofv3 kernel trace → 토큰당 커널 수·시간을 커널 종류별로. 토큰 경계는 D2H 복사(로짓) 끝.
#   argv: run_dir [접두사=a] [마지막 토큰 수=32]
import csv, sys, collections
d = sys.argv[1]; p = sys.argv[2] if len(sys.argv) > 2 else 'a'; N = int(sys.argv[3]) if len(sys.argv) > 3 else 32
D = sorted(int(r['End_Timestamp']) for r in csv.DictReader(open(f'{d}/{p}_memory_copy_trace.csv')) if 'DEVICE_TO_HOST' in r['Direction'])
w0, w1 = D[-N - 1], D[-1]
K = sorted((int(r['Start_Timestamp']), int(r['End_Timestamp']), r['Kernel_Name']) for r in csv.DictReader(open(f'{d}/{p}_kernel_trace.csv')))
K = [k for k in K if w0 <= k[0] < w1]
def short(n):
    n = n.replace('void ', '').split('(')[0]
    return n.split('<')[0] + ('<' + n.split('<')[1].split(',')[0][:24] + '>' if '<' in n else '')
t = collections.Counter(); c = collections.Counter(); lo = collections.Counter()
for s, e, n in K: k = short(n); t[k] += e - s; c[k] += 1
busy = sum(e - s for s, e, n in K)
gap = [K[i][0] - K[i-1][1] for i in range(1, len(K))]
print(f"tokens {N}: wall/tok {(w1-w0)/N/1e6:.2f} ms, kernels/tok {len(K)/N:.0f}, kernel time/tok {busy/N/1e6:.2f} ms, "
      f"gaps/tok {sum(g for g in gap if g > 0)/N/1e6:.2f} ms (median gap {sorted(gap)[len(gap)//2]/1e3:.1f} us)")
dur = sorted(e - s for s, e, n in K)
for q in (0.1, 0.25, 0.5, 0.75, 0.9, 0.99): print(f"  kernel duration p{int(q*100)}: {dur[int(q*len(dur))]/1e3:.1f} us")
small = sum(x for x in dur if x < 20e3); print(f"  kernels < 20 us: {sum(1 for x in dur if x < 20e3)/N:.0f}/tok, {small/N/1e6:.2f} ms/tok")
print(f"{'ms/tok':>7} {'n/tok':>6} {'avg us':>7}  kernel")
for k, v in t.most_common(40): print(f"{v/N/1e6:7.2f} {c[k]/N:6.1f} {v/c[k]/1e3:7.1f}  {k}")
