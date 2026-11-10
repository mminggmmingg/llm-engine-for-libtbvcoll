# MoE 구간(AR 받아 더하기 + rms_norm 다음 → 다음 AR 받아 더하기 + rms_norm 까지) 하나의 커널 순서·시간·앞 빈틈을 구간 위치별 중앙값으로:
# python3 -I segtrace.py <a_kernel_trace.csv> [건너뛸 토큰=4]
import csv, sys, collections, statistics as st
f = sys.argv[1]; skip = int(sys.argv[2]) if len(sys.argv) > 2 else 4
K = sorted((int(r['Start_Timestamp']), int(r['End_Timestamp']), r['Kernel_Name'].replace('void ', '').replace('(ggml_type)', 't'),
            int(r['Grid_Size_X']) * int(r['Grid_Size_Y']) * int(r['Grid_Size_Z']), int(r['Workgroup_Size_X']), int(r['VGPR_Count']), int(r['LDS_Block_Size']))
           for r in csv.DictReader(open(f)))
LM = int(sys.argv[3]) if len(sys.argv) > 3 else 3973120
ends = [i for i, k in enumerate(K) if k[3] == LM]
toks = [(ends[j] + 1, ends[j + 1] + 1) for j in range(skip, len(ends) - 1)]
toks = [(a, b) for a, b in toks if (K[b - 1][1] - K[a - 1][1]) < (float(sys.argv[4])*1e6 if len(sys.argv) > 4 else 60e6)]
short = lambda n: n.split('(')[0][:70]
is_ar = lambda k: k[2].startswith('rms_norm_f32<1024, 1, true, true, false, false, true') and k[3] in (4096, 8192, 12288, 16384)
segs = collections.defaultdict(list)   # signature -> list of [(dur, gap)]
for a, b in toks:
    idx = [i for i in range(a, b) if is_ar(K[i])]
    for s, e in zip(idx, idx[1:]):
        ks = K[s:e + 1]
        sig = tuple((short(k[2]), k[3], k[4]) for k in ks)
        segs[sig].append([(k[1] - k[0], k[0] - K[s + j - 1][1] if j else 0) for j, k in enumerate(ks)])
for sig, rows in sorted(segs.items(), key=lambda x: -len(x[1])):
    moe = any('glu_q8<t23' in n for n, _, _ in sig)
    tot = st.median(sum(d + g for d, g in r[1:]) for r in rows)
    kern = st.median(sum(d for d, g in r[1:]) for r in rows)
    gaps = st.median(sum(g for d, g in r[1:]) for r in rows)
    print(f"\n## {'MoE' if moe else '그 밖'} 구간: {len(rows)}번 나옴 ({len(rows) / len(toks):.1f}/토큰), 커널 {len(sig) - 1}개, 앞 AR 끝 → 다음 AR 끝 {tot / 1e3:.1f} µs"
          f" = 커널 {kern / 1e3:.1f} + 빈틈 {gaps / 1e3:.1f}")
    print("| # | 커널 | grid | 블록 | µs | 앞 빈틈 µs |")
    print("|---:|---|---:|---:|---:|---:|")
    for j, (n, g, w) in enumerate(sig):
        d = st.median(r[j][0] for r in rows) / 1e3; gp = st.median(r[j][1] for r in rows) / 1e3
        print(f"| {j} | `{n}` | {g} | {w} | {d:.1f} | {gp:.1f} |")
    if not moe and len(rows) / len(toks) < 0.9: break
