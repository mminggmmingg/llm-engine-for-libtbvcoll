# prof2node.sh PROFARGS="--pmc FETCH_SIZE" 기록(a_counter_collection.csv)에서 커널마다 토큰당 GPU 읽기(L2 밖) 바이트.
#   argv: run_dir [ntok 기준 = gated_delta_net 커널 수 / 36]
# gfx1151 의 FETCH_SIZE 는 읽은 바이트의 절반을 KB 로 센다(inferwatch readbw 보정 11-10) → 바이트 = 값 × 1024 × 2.
# 프로파일러 아래 값(커널이 줄지어 돈다): 바이트는 그대로지만 캐시 재사용은 평소와 다를 수 있다.
import csv, sys, collections, re
d = sys.argv[1]
rows = list(csv.DictReader(open(d + '/a_counter_collection.csv')))
by, cnt = collections.Counter(), collections.Counter()
seen = set()
for r in rows:
    if r.get('Counter_Name', 'FETCH_SIZE') != 'FETCH_SIZE':
        continue
    key = (r.get('Dispatch_Id'), r.get('Correlation_Id'))
    n = r['Kernel_Name'].replace('void ', '').split('(')[0]
    base = n.split('<')[0]
    if base in ('mul_mat_vec_q', 'rms_norm_f32', 'mul_mat_vec_f', 'quantize_q8_1'):
        n = base + '<' + n.split('<', 1)[1][:24] if '<' in n else base
    else:
        n = base
    by[n] += float(r['Counter_Value']) * 1024 * 2
    if key not in seen:
        seen.add(key); cnt[n] += 1
ntok = cnt.get('gated_delta_net_cuda', 0) / 36 if len(sys.argv) < 3 else float(sys.argv[2])
tot = sum(by.values()) / ntok
print(f'{d.rsplit("/",1)[-1]}: tokens {ntok:.1f}, GPU read (L2 miss) {tot/1e9:.3f} GB/token, kernels/token {sum(cnt.values())/ntok:.0f}')
cat = collections.Counter()
def category(n):
    if 'moe' in n: return 'experts (mmvq moe)'
    if 'gated_delta_net' in n: return 'GDN recurrence (state)'
    if n.startswith('mul_mat') or 'k_hc_up_pre' in n or 'shexp_tail' in n or 'comm_out' in n or 'glu_q8' in n or 'gdn_gates' in n: return 'other matmul'
    if 'flash_attn' in n or 'idx_k' in n: return 'attention'
    return 'elementwise/norm/copy'
for n, b in by.items():
    cat[category(n)] += b
for k, v in cat.most_common():
    print(f'  {v/ntok/1e9:6.3f} GB  {k}')
print('top kernels:')
for n, b in by.most_common(25):
    print(f'  {b/ntok/1e6:8.1f} MB/tok  {cnt[n]/ntok:6.1f}/tok  {n}')
