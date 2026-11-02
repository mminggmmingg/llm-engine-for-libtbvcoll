# 1노드 rocprofv3 커널 기록 → 토큰 1개 시간 명세(커널 시간 + 앞 빈틈)를 TP 에서의 성격별로: tokspec.py <run_dir> [접두사=a] [토큰=32]
#   층 안 위치로 분류: hc 경계(rms_norm<1024>·양자화·hc down/up 행렬곱·scale·silu·hc_pre·hc_post)는 두 노드가 똑같이 함(복제),
#   그 밖의 mmvq 는 나뉘는 행렬곱, 라우터·topk·MoE 합치기·shared expert 게이트·FFN 끝 원소별은 복제, GDN/attention 작은 연산은 머리 단위로 나뉨.
import csv, sys, collections
d = sys.argv[1]; p = sys.argv[2] if len(sys.argv) > 2 else 'a'; N = int(sys.argv[3]) if len(sys.argv) > 3 else 32
D = sorted(int(r['End_Timestamp']) for r in csv.DictReader(open(f'{d}/{p}_memory_copy_trace.csv')) if 'DEVICE_TO_HOST' in r['Direction'])
K = sorted(((int(r['Start_Timestamp']), int(r['End_Timestamp']), r['Kernel_Name']) for r in csv.DictReader(open(f'{d}/{p}_kernel_trace.csv'))))
bounds = D[-(N+1):]
cat_t = collections.defaultdict(float); cat_g = collections.defaultdict(float); cat_n = collections.defaultdict(int)
wall = 0
for t0, t1 in zip(bounds[:-1], bounds[1:]):
    ks = [k for k in K if t0 <= k[0] < t1]
    wall += (t1 - t0)
    prev_end = t0; pos = 0; seg = 'pre'; seg_kind = None
    # 구간 종류(GDN·attn·FFN·출력)는 구간 안 커널로 정한다: 미리 훑어 hc_post 사이 구간마다 표시
    segs = []; cur = []
    for k in ks:
        cur.append(k)
        if 'dsv4_hc_post' in k[2]:
            segs.append(cur); cur = []
    segs.append(cur)
    for s in segs:
        names = ' '.join(k[2] for k in s)
        kind = 'ffn' if 'topk_moe' in names else 'gdn' if 'gated_delta_net' in names else 'attn' if 'flash_attn' in names else 'other'
        nmm = 0; after_pre = False
        for k in s:
            n = k[2]
            if 'dsv4_hc_pre' in n:
                c = 'C hc 작은 연산(복제)'; after_pre = True
            elif 'dsv4_hc_post' in n:
                c = 'C hc 작은 연산(복제)'
            elif not after_pre:
                if 'mul_mat_vec_q' in n:
                    c = 'B hc 행렬곱(복제)'; nmm += 1
                elif 'quantize_q8_1' in n:
                    c = 'B hc 행렬곱(복제)'
                else:
                    c = 'C hc 작은 연산(복제)'
            elif 'mul_mat_vec_q' in n or 'quantize_q8_1' in n:
                c = 'A 나뉘는 행렬곱' if kind != 'other' else 'A 나뉘는 행렬곱(출력 머리)' if 'mul_mat_vec_q' in n else 'A 나뉘는 행렬곱(출력 머리)'
            elif 'mul_mat_vec_f' in n or 'topk_moe' in n or 'moe_weighted' in n:
                c = 'D 라우터·MoE 합치기·shexp 게이트(복제)'
            elif kind == 'ffn':
                c = 'D 라우터·MoE 합치기·shexp 게이트(복제)'
            elif kind in ('gdn', 'attn'):
                c = 'E GDN·attn 작은 연산(머리 단위로 나뉨)'
            else:
                c = 'F 그 밖(입력·출력 처리)'
            cat_t[c] += (k[1] - k[0]); cat_g[c] += max(0, k[0] - prev_end); cat_n[c] += 1
            prev_end = max(prev_end, k[1])
    cat_g['G 토큰 끝 빈틈(호스트)'] += max(0, t1 - prev_end)
T = len(bounds) - 1
print(f"tokens {T}, wall/tok {wall/T/1e6:.2f} ms")
print(f"{'구분':40s} {'커널/토큰':>9s} {'커널 ms':>8s} {'빈틈 ms':>8s}")
for c in sorted(set(cat_t) | set(cat_g)):
    print(f"{c:40s} {cat_n[c]/T:9.0f} {cat_t[c]/T/1e6:8.2f} {cat_g[c]/T/1e6:8.2f}")
print(f"{'합':40s} {sum(cat_n.values())/T:9.0f} {sum(cat_t.values())/T/1e6:8.2f} {sum(cat_g.values())/T/1e6:8.2f}")
