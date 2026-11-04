"""halogen 커널 기록(rocprofv3 --kernel-trace CSV)으로 디코드 한 토큰(=k_argmax_final 사이)마다: 커널 수, GPU 가 커널을 돌린 몫,
커널 사이 빈틈 분포, 가장 긴 빈틈(호스트 대기 자리), 시간 많이 쓰는 커널 — ktrace_steps.py <fs_kernel_trace.csv> [토큰 수 상한]"""
import csv, sys, statistics as st, collections
rows = sorted((int(r['Start_Timestamp']), int(r['End_Timestamp']), r['Kernel_Name']) for r in csv.DictReader(open(sys.argv[1])))
print(f'kernels {len(rows)}, zero-length {sum(1 for s, e, n in rows if e <= s)}')
def short(n):
    n = n.replace('void ', '').replace('(anonymous namespace)::', '').split('(')[0]
    return n.split('<')[0][-48:]
ends = [i for i, k in enumerate(rows) if 'argmax_final' in k[2]]
steps = []
for a, b in zip(ends, ends[1:]):
    ks = rows[a + 1:b + 1]
    span = ks[-1][1] - rows[a][1]
    busy = sum(e - s for s, e, n in ks)
    gaps = [ks[i][0] - (ks[i - 1][1] if i else rows[a][1]) for i in range(len(ks))]
    steps.append((len(ks), span, busy, gaps, ks))
# decode 단계만: 커널 수가 가장 흔한 값 ±10% (prefill·MTP verify 제외)
common = collections.Counter(s[0] // 10 * 10 for s in steps).most_common(1)[0][0]
dec = [s for s in steps if abs(s[0] - common) <= max(20, common // 10)]
lim = int(sys.argv[2]) if len(sys.argv) > 2 else len(dec)
dec = dec[:lim]
print(f'decode-like steps {len(dec)} (of {len(steps)} argmax-to-argmax), kernels/step median {st.median(s[0] for s in dec)}')
span = st.median(s[1] for s in dec) / 1e6; busy = st.median(s[2] for s in dec) / 1e6
print(f'per step: span {span:.2f} ms, kernels running {busy:.2f} ms ({100*busy/span:.1f}%), idle {span-busy:.2f} ms')
gsum = st.median(sum(g for g in s[3] if g <= 100e3) for s in dec) / 1e6; bsum = st.median(sum(g for g in s[3] if g > 100e3) for s in dec) / 1e6
print(f'  idle split: small gaps between kernels (<=100 us) {gsum:.2f} ms, long waits (>100 us) {bsum:.2f} ms')
allg = sorted(g for s in dec for g in s[3])
q = lambda p: allg[int(p * (len(allg) - 1))] / 1e3
print(f'gaps between kernels (us): p10 {q(.1):.1f} med {q(.5):.1f} p90 {q(.9):.1f} p99 {q(.99):.1f} max {q(1):.1f}')
big = collections.Counter()
for s in dec:
    for i, g in enumerate(s[3]):
        if g > 100e3: big[short(s[4][i][2])] += 1
print('kernels that start after a >100 us gap (per step):', {k: round(v / len(dec), 2) for k, v in big.most_common(6)})
tot = collections.Counter(); cnt = collections.Counter()
for s in dec:
    for b0, e0, n in s[4]: tot[short(n)] += e0 - b0; cnt[short(n)] += 1
print('top kernels per step (us, count):')
for n, t in tot.most_common(14): print(f'  {t/len(dec)/1e3:8.1f} us  x{cnt[n]/len(dec):5.1f}  {n}')
