# 토큰 하나(decode, A 서버)의 GPU 시간 장부: python3 -I budget.py <a_kernel_trace.csv> [건너뛸 토큰=4]
# 토큰 = 출력층 행렬곱(grid 3973120) 끝 → 다음 출력층 끝. 그 안의 커널 시간을 묶음별로, 커널 사이 빈틈을 크기별로 나눈다.
# AR 기다림이 커널 안에 있는 것(COMM_FUSE 의 rms_norm, shared expert down 꼬리)은 하위 10% 길이를 계산 몫, 나머지를 기다림으로 본다.
import csv, sys, collections, statistics as st
f = sys.argv[1]; skip = int(sys.argv[2]) if len(sys.argv) > 2 else 4
K = sorted((int(r['Start_Timestamp']), int(r['End_Timestamp']), r['Kernel_Name'].replace('void ', '').replace('(ggml_type)', 't'),
            int(r['Grid_Size_X']) * int(r['Grid_Size_Y']) * int(r['Grid_Size_Z']), int(r['Workgroup_Size_X'])) for r in csv.DictReader(open(f)))
name = lambda k: k[2].split('(')[0]
LM = 3973120
ends = [i for i, k in enumerate(K) if k[3] == LM]
toks = [(ends[j] + 1, ends[j + 1] + 1) for j in range(skip, len(ends) - 1)]   # kernels after one lm head up to and including the next
# only decode tokens: windows shorter than 60 ms
toks = [(a, b) for a, b in toks if (K[b - 1][1] - K[a - 1][1]) < 60e6]
def group(k):
    n, g = name(k), k[3]
    if n.startswith('mul_mat_vec_q<t6') and g == 262144: return 'MM GDN qkv+gate (Q5_0, 나뉨)'
    if n.startswith('mul_mat_vec_q<t6') and g == 81920: return 'MM ssm_out (Q5_0, 나뉨)'
    if n.startswith('mul_mat_vec_q<t6') and g == 196608: return 'MM attn_q (Q5_0, 나뉨)'
    if n.startswith('mul_mat_vec_q<t6') and g == 8192: return 'MM attn_k/v (Q5_0, 나뉨)'
    if n.startswith('mul_mat_vec_q<t8') and g == 81920: return 'MM attn_output (Q8_0, 나뉨)'
    if g == LM: return 'MM 출력층 (Q6_K, 나뉨)'
    if n.startswith('mul_mat_vec_q_glu_q8<t23'): return 'MM MoE gate+up (IQ4_XS, 전문가 나뉨)'
    if n.startswith('mul_mat_vec_q<t20'): return 'MM MoE down (IQ4_NL, 전문가 나뉨)'
    if n.startswith('k_hc_up_pre'): return 'MM hc up + pre (Q8_0, 복제)'
    if n.startswith('mul_mat_vec_q<t14') and g == 10368: return 'MM hc down (Q6_K, 복제)'
    if n.startswith('mul_mat_vec_f<__hip_bfloat16'): return 'MM 라우터·indexer q (BF16, 복제)'
    if n.startswith('mul_mat_vec_q_glu_q8<t6'): return 'MM shared expert gate+up (Q5_0, 복제)'
    if n.startswith('mul_mat_vec_q_shexp_tail'): return 'MM shared expert down + 꼬리 (Q5_0, 복제, AR 기다림 포함)'
    if n.startswith('mul_mat_vec_q') or n.startswith('mul_mat_vec_f'): return 'MM 그 밖 (작은 행렬곱)'
    if n.startswith('rms_norm_f32<1024, 1, true, true, false, false, true, false, true>'.split('(')[0]) and g == 4096: return 'AR 받아 더하기 + rms_norm (AR 기다림 포함)'
    if 'comm' in n: return 'AR 부분합 내보내기'
    if n.startswith('gated_delta_net') or n.startswith('ssm_conv') or 'gdn' in n: return 'GDN(선형 attention) 연산'
    if 'flash_attn' in n or n.startswith('idx_') or 'rope' in n or 'argsort' in n or 'topk' in n.lower() and 'moe' not in n: return 'attention·indexer 연산'
    if 'topk_moe' in n or 'moe_weighted' in n or 'argmax' in n.lower() or 'k_argmax' in n: return '라우팅·MoE 합·argmax'
    return '그 밖 작은 커널'
wait_groups = {'AR 받아 더하기 + rms_norm (AR 기다림 포함)', 'MM shared expert down + 꼬리 (Q5_0, 복제, AR 기다림 포함)'}
dur = collections.defaultdict(list)
for a, b in toks:
    for k in K[a:b]:
        dur[group(k)].append(k[1] - k[0])
floor = {g: sorted(v)[len(v) // 10] for g, v in dur.items() if g in wait_groups}
T = collections.defaultdict(float); N = collections.Counter()
gaps = collections.defaultdict(float); ngap = collections.Counter(); span = 0.0
for a, b in toks:
    span += (K[b - 1][1] - K[a - 1][1]) / 1e3
    prev_end = K[a - 1][1]
    for k in K[a:b]:
        g = group(k); d = (k[1] - k[0]) / 1e3
        if g in wait_groups:
            c = min(d, floor[g] / 1e3)
            T[g + ' — 계산'] += c; T['AR 기다림 (커널 안)'] += d - c
        else:
            T[g] += d
        N[g] += 1
        gp = (k[0] - prev_end) / 1e3
        if gp > 0:
            cls = '단계 경계(>200 µs)' if gp > 200 else '커널 사이 빈틈 20–200 µs' if gp > 20 else '커널 사이 빈틈 5–20 µs' if gp > 5 else '커널 사이 빈틈 ≤5 µs'
            gaps[cls] += gp; ngap[cls] += 1
        prev_end = max(prev_end, k[1])
n = len(toks)
tok_ms = span / n / 1000
# MB read per call (A node, TP=2 halves for split tensors), from the tensor shapes (fixcost/bneck-1108/bytes.py)
MB = {'MM GDN qkv+gate (Q5_0, 나뉨)': 8192*2560*22/32/1e6, 'MM ssm_out (Q5_0, 나뉨)': 2560*3072*22/32/1e6, 'MM attn_q (Q5_0, 나뉨)': 6144*2560*22/32/1e6,
      'MM attn_output (Q8_0, 나뉨)': 2560*3072*34/32/1e6, 'MM attn_k/v (Q5_0, 나뉨)': 256*2560*22/32/1e6, 'MM 출력층 (Q6_K, 나뉨)': 124160*2560*210/256/1e6,
      'MM MoE gate+up (IQ4_XS, 전문가 나뉨)': 10*2*320*2560*136/256/1e6, 'MM MoE down (IQ4_NL, 전문가 나뉨)': 10*2560*320*18/32/1e6,
      'MM hc up + pre (Q8_0, 복제)': 10240*320*34/32/1e6, 'MM hc down (Q6_K, 복제)': 324*10240*210/256/1e6,
      'MM 라우터·indexer q (BF16, 복제)': 512*2560*2/1e6, 'MM shared expert gate+up (Q5_0, 복제)': 2*640*2560*22/32/1e6,
      'MM shared expert down + 꼬리 (Q5_0, 복제, AR 기다림 포함)': 2560*640*22/32/1e6}
print(f"decode 토큰 {n}개, 토큰당 {tok_ms:.2f} ms(A 서버 GPU 시간선), 커널 {sum(N.values())/n:.0f}개/토큰\n")
print("| 몫 | ms/토큰 | 토큰의 % | 회/토큰 | MB/토큰 | 실효 GB/s |\n|---|---:|---:|---:|---:|---:|")
rows = [(v / n / 1000, g) for g, v in T.items()] + [(v / n / 1000, g) for g, v in gaps.items()]
tot_mb = 0.0
for ms, g in sorted(rows, reverse=True):
    base = g.replace(' — 계산', '')
    cnt = N[base] / n if base in N else ngap[g] / n if g in ngap else 0
    mb = MB.get(base, 0) * cnt
    tot_mb += mb
    extra = f"{mb:.0f} | {mb/ms:.0f}" if mb else " | "
    print(f"| {g} | {ms:.3f} | {100*ms/tok_ms:.1f} | {cnt:.1f} | {extra} |")
cat = collections.defaultdict(float)
for ms, g in rows:
    c = ('행렬곱(가중치 읽기)' if g.startswith('MM') else 'AR 기다림(커널 안)' if g.startswith('AR 기다림') else
         '커널 사이 빈틈' if '빈틈' in g or '경계' in g else '행렬곱 밖 커널')
    cat[c] += ms
print(f"\n- 묶음 합: " + ", ".join(f"{c} {v:.2f} ms({100*v/tok_ms:.0f}%)" for c, v in sorted(cat.items(), key=lambda x: -x[1])))
print(f"- 행렬곱이 읽는 가중치 {tot_mb:.0f} MB/토큰, 230 GB/s 이면 {tot_mb/230:.2f} ms, 239.7 GB/s 이면 {tot_mb/239.7:.2f} ms")
print(f"- 기다림이 든 커널의 계산 몫(하위 10% 길이): " + ", ".join(f"{g} {floor[g]/1e3:.1f} µs" for g in floor))
print(f"- 커널 사이 빈틈 ≤5 µs 평균 {gaps['커널 사이 빈틈 ≤5 µs']/max(ngap['커널 사이 빈틈 ≤5 µs'],1)/1e3*1000:.2f} µs")
