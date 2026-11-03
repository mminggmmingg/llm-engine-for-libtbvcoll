# A 서버 커널 기록(prof2node.sh)을 부분그래프(AR 사이)로 나눠, 단계 안 위치별(GDN·attention·MoE)로 커널 시간과 빈틈을 본다.
#   argv: run_dir [접두사=a]
#   부분그래프 = 앞 AR 의 k_comm_wait_add 끝 ~ 다음 k_comm_wait_add 시작. 단계 경계 = 부분그래프 길이 1 ms 넘음(출력층·발행 기다림).
#   종류는 들어 있는 커널로 정한다(프로파일러 아래에서는 단계 경계를 놓쳐 위치 번호가 밀릴 수 있다).
import csv, sys, collections, statistics as st
d = sys.argv[1]; p = sys.argv[2] if len(sys.argv) > 2 else 'a'
K = sorted((int(r['Start_Timestamp']), int(r['End_Timestamp']), r['Kernel_Name']) for r in csv.DictReader(open(f'{d}/{p}_kernel_trace.csv')))
def short(n):
    n = n.replace('void ', '').split('(')[0]
    return n.split('<')[0] + ('<' + n.split('<')[1].split(',')[0][:20] + '>' if '<' in n else '')
W = [i for i, k in enumerate(K) if 'k_comm_wait_add' in k[2]]
subs = []  # (start, end, kernels between)
for a, b in zip(W, W[1:]):
    ks = K[a + 1:b]
    subs.append((K[a][1], K[b][0], ks))
# 부분그래프 종류는 들어 있는 커널로: GDN(gated_delta_net)·attention(flash_attn)·MoE(topk_moe), 단계 첫 부분그래프(1 ms 넘음)는 뺀다
groups = collections.defaultdict(list)
for s, e, ks in subs:
    if e - s > 1e6:
        continue
    names = ' '.join(k[2] for k in ks)
    kind = 'gdn' if 'gated_delta_net' in names else 'attn' if 'flash_attn' in names else 'moe' if 'topk_moe' in names else 'other'
    groups[kind].append((s, e, ks))
for kind in ('gdn', 'attn', 'moe', 'other'):
    g = groups[kind]
    if not g:
        continue
    span = st.median(e - s for s, e, ks in g) / 1e3
    busy = st.median(sum(k[1] - k[0] for k in ks) for s, e, ks in g) / 1e3
    nk = st.median(len(ks) for s, e, ks in g)
    print(f'== {kind}: {len(g)} subgraphs, span {span:.1f} us, kernels {nk:.0f}, kernel time {busy:.1f} us, gaps {span - busy:.1f} us')
    per = collections.defaultdict(list)
    for s, e, ks in g:
        c = collections.Counter()
        t = collections.Counter()
        for k in ks:
            n = short(k[2]); c[n] += 1; t[n] += k[1] - k[0]
        for n in c:
            per[n].append((c[n], t[n]))
    rows = sorted(per.items(), key=lambda kv: -st.median(x[1] for x in kv[1]))
    for n, v in rows[:14]:
        print(f'   {st.median(x[1] for x in v)/1e3:7.1f} us  x{st.median(x[0] for x in v):4.1f}  {n}')
