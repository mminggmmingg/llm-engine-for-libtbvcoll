# 깊이별 A 서버 커널 기록(prof2node.sh, llama-bench -d <깊이> -p 0 -n N)에서 디코드 구간 커널을 토큰당으로 비교한다.
#   kdepth.py <이름>=<prof2node 폴더> [...]
# 디코드 구간 = 마지막 prefill 행렬곱(mul_mat_q, 묶음 처리) 커널 뒤. 토큰 수 = flash_attn 계열 첫 커널 수 / QSA 층 수(12).
# 커널 이름(짧게)마다 토큰당 시간 합(µs)과 토큰당 개수. 깊이에 따라 커지는 줄이 문맥에 비례하는 몫이다.
import csv, sys, collections

N_QSA = 12

def short(n):
    n = n.replace('void ', '').split('(')[0]
    base = n.split('<')[0]
    targs = n[len(base):]
    return base + (targs[:48] if targs else '')

runs = []
for a in sys.argv[1:]:
    name, d = a.split('=', 1)
    K = sorted((int(r['Start_Timestamp']), int(r['End_Timestamp']), r['Kernel_Name']) for r in csv.DictReader(open(f'{d}/a_kernel_trace.csv')))
    last_pp = max((i for i, k in enumerate(K) if 'mul_mat_q<' in k[2] or 'mul_mat_q_stream_k' in k[2]), default=-1)
    D = K[last_pp + 1:]
    fa = [k for k in D if k[2].replace('void ', '').startswith('flash_attn_tile') or k[2].replace('void ', '').startswith('flash_attn_ext')]
    ntok = max(1, round(len(fa) / N_QSA))
    t = collections.defaultdict(float); n = collections.Counter()
    for k in D:
        s = short(k[2]); t[s] += (k[1] - k[0]) / 1e3; n[s] += 1
    span = (D[-1][1] - D[0][0]) / 1e3 / ntok if D else 0
    runs.append((name, ntok, span, sum(t.values()) / ntok, {s: (t[s] / ntok, n[s] / ntok) for s in t}))
    print(f'{name}: decode kernels {len(D)}, tokens {ntok}, span/token {span:.0f} us, kernel busy/token {sum(t.values()) / ntok:.0f} us')

names = sorted({s for r in runs for s in r[4]}, key=lambda s: -max(r[4].get(s, (0, 0))[0] for r in runs))
print('\nkernel (per token: us, count)'.ljust(62) + ''.join(f'{r[0]:>18}' for r in runs))
for s in names:
    cells = []
    for r in runs:
        v = r[4].get(s)
        cells.append(f'{v[0]:9.1f} ({v[1]:4.0f})' if v else '')
    print(s[:60].ljust(62) + ''.join(f'{c:>18}' for c in cells))
