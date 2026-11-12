# 프롬프트 처리(문맥 채우기 + pp) 커널 기록(prof2node.sh, BARGS="-p 512 -n 0 -d <깊이> -r 1")에서 커널 이름(짧게)별 시간 합·개수·몫.
#   ppk.py <prof2node 폴더> [줄 수=30]
# 묶음(512토큰) 수 = flash_attn 계열 커널 수 / QSA 층 수(12). 묶음당 ms 도 찍는다. 디코드 단계가 없는 회(-n 0)에 쓴다.
import csv, sys, collections
d = sys.argv[1]; top = int(sys.argv[2]) if len(sys.argv) > 2 else 30
def short(n):
    n = n.replace('void ', '').split('(')[0]
    base = n.split('<')[0]
    return base + (n[len(base):][:40] if n[len(base):] else '')
K = [(int(r['Start_Timestamp']), int(r['End_Timestamp']), r['Kernel_Name']) for r in csv.DictReader(open(f'{d}/a_kernel_trace.csv'))]
t = collections.defaultdict(float); n = collections.Counter()
for s, e, k in K:
    sk = short(k); t[sk] += (e - s) / 1e6; n[sk] += 1
tot = sum(t.values()); span = (max(k[1] for k in K) - min(k[0] for k in K)) / 1e9
nfa = sum(c for k, c in n.items() if k.startswith('flash_attn')); nub = max(1, round(nfa / 12))
print(f'{d}: kernels {len(K)}, busy {tot/1e3:.1f} s, span {span:.1f} s, ubatches≈{nub}, busy/ubatch {tot/nub:.0f} ms')
print('kernel'.ljust(58) + f'{"ms":>10}{"count":>8}{"%":>7}{"ms/ub":>9}')
for k in sorted(t, key=lambda k: -t[k])[:top]:
    print(k[:56].ljust(58) + f'{t[k]:10.0f}{n[k]:8d}{100*t[k]/tot:7.1f}{t[k]/nub:9.1f}')
