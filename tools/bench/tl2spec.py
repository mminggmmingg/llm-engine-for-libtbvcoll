# 2노드 시간 명세: tl2spec.py <runs/tl2node-...> [--seq N(시간 순서로 보일 AR 수, 기본 4)] [--svg file]
#   입력: {a,b}/a_kernel_trace.csv (rocprofv3, ns), {a,b}/tl.txt (GGML_RPC_COMM_PROF_TL, us: q entry pending ready sent end land)
#   - 노드 안 정렬: rocprof 커널 시각은 GPU 시계를 바꾼 값이라 호스트 시계와 어긋날 수 있다. AR 마다 받기 대기 커널(k_comm_wait_add)이
#     상대 부분합 도착(land) 뒤 ≈2.5 us 에 끝나도록 노드별 차이를 구한다(i 번째 wait_add ↔ 타임라인 i 번째 줄, 둘 다 디코드 AR 만).
#   - 노드 사이 정렬: 같은 AR 번호 q 에서 (B.land − A.sent), (A.land − B.sent) 의 낮은 백분위로 시계 차이(대칭 지연 가정).
#   - 분류: tokspec.py 와 같은 층 안 위치 기준 + 통신(상대 기다림 = wait_add 시작~land, 더하기 = land~끝, 보내기 복사 = wait_add 바로 앞 복사 커널).
import csv, sys, bisect, collections, statistics as st

args = sys.argv[1:]
d = args[0]
nseq = int(args[args.index('--seq') + 1]) if '--seq' in args else 4
svg = args[args.index('--svg') + 1] if '--svg' in args else None

def load(n):
    K = sorted((int(r['Start_Timestamp']) / 1e3, int(r['End_Timestamp']) / 1e3, r['Kernel_Name'])
               for r in csv.DictReader(open(f'{d}/{n}/a_kernel_trace.csv')))
    tl = [list(map(int, l.split())) for l in open(f'{d}/{n}/tl.txt')]
    tl = [r for r in tl if all(r[1:])]
    return K, tl

def short(name):
    return name.split('(')[0].replace('void ', '')[:48]

# ---- 분류(노드 하나의 커널 열 전체) ----
def classify(K):
    cats = []
    seg = []; segs = []
    for i, k in enumerate(K):
        seg.append(i)
        if 'dsv4_hc_post' in k[2]:
            segs.append(seg); seg = []
    segs.append(seg)
    cat = [None] * len(K)
    for s in segs:
        names = ' '.join(K[i][2] for i in s)
        kind = 'ffn' if 'topk_moe' in names else 'gdn' if 'gated_delta_net' in names else 'attn' if 'flash_attn' in names else 'other'
        after_pre = False
        for i in s:
            n = K[i][2]
            if 'k_comm_wait_add' in n:
                c = 'X 받기(대기+더하기)'
            elif 'dsv4_hc_pre' in n:
                c = 'C hc 작은 연산(복제)'; after_pre = True
            elif 'dsv4_hc_post' in n:
                c = 'C hc 작은 연산(복제)'
            elif not after_pre:
                c = 'B hc 행렬곱(복제)' if ('mul_mat_vec_q' in n or 'quantize_q8_1' in n) else 'C hc 작은 연산(복제)'
            elif 'mul_mat_vec_q' in n or 'quantize_q8_1' in n:
                c = 'A 나뉘는 행렬곱'
            elif 'mul_mat_vec_f' in n or 'topk_moe' in n or 'moe_weighted' in n or kind == 'ffn':
                c = 'D 라우터·MoE 합치기(복제)'
            elif kind in ('gdn', 'attn'):
                c = 'E GDN·attn 작은 연산'
            else:
                c = 'F 그 밖'
            cat[i] = c
    # 받기 커널 바로 앞의 복사 커널은 보내기용(부분합 → coherent 호스트 메모리)
    for i, k in enumerate(K):
        if 'k_comm_wait_add' in k[2]:
            j = i - 1
            while j >= 0 and 'copyBuffer' not in K[j][2] and i - j < 4:
                j -= 1
            if j >= 0 and 'copyBuffer' in K[j][2]:
                cat[j] = 'Y 보내기 복사'
    return cat

nodes = {}
for n in 'ab':
    K, tl = load(n)
    cat = classify(K)
    wa = [i for i, k in enumerate(K) if 'k_comm_wait_add' in k[2]]
    # 노드 안 정렬: i 번째 wait_add ↔ 타임라인 i 번째(q 오름차순) — 끝 시각이 land 뒤 2.5 us
    tl.sort(key=lambda r: r[0])
    m = min(len(wa), len(tl))
    diffs = sorted(K[wa[i]][1] - tl[i][6] for i in range(m))
    off_k = diffs[len(diffs) // 5] - 2.5          # 커널 시각 − 호스트 시각 (낮은 쪽 20 백분위: GPU 가 늦게 와 기다리지 않은 AR 을 피함)
    nodes[n] = dict(K=K, tl=tl, cat=cat, wa=wa, off_k=off_k, m=m,
                    spread=(diffs[len(diffs) // 2] - diffs[len(diffs) // 5]))

# 노드 사이 정렬(호스트 시계): B − A
ta = {r[0]: r for r in nodes['a']['tl']}; tb_raw = {r[0]: r for r in nodes['b']['tl']}
p = lambda v, f: v[int(len(v) * f)]
# 두 노드의 AR 번호가 처음에 몇 개 어긋날 수 있다: B 번호 = A 번호 + s 인 s 를, AR 별 시계 차 추정
# ((B.land − A.sent) − (A.land − B.sent))/2 가 가장 고르게 나오는 값으로 고른다(가운데 절반만 사용)
best = None
for s in range(-8, 9):
    qs = [q for q in sorted(ta) if q + s in tb_raw]
    qs = qs[len(qs) // 4: len(qs) * 3 // 4]
    if len(qs) < 20:
        continue
    o = sorted(((tb_raw[q + s][6] - ta[q][4]) - (ta[q][6] - tb_raw[q + s][4])) / 2 for q in qs)
    spread = p(o, 0.75) - p(o, 0.25)
    if best is None or spread < best[1]:
        best = (s, spread)
shift = best[0]
# 시계 차는 서버가 연결될 때 주고받은 값(B 가 rank 0: "peer - self" = A − B)을 우선 쓴다 — 한쪽이 늘 늦으면 타임라인만으로는 못 구함
off_ab = None
for l in open(f'{d}/b/rpc.log', errors='replace'):
    if '[comm_clock] peer - self' in l:
        off_ab = -float(l.split('=')[1].split('us')[0]); shift = 0
if off_ab is None:
    print("주의: comm_clock 없음 — 타임라인으로 추정(한쪽이 늘 늦으면 틀림)")
tb = {q - shift: r for q, r in tb_raw.items()}         # B 의 줄을 A 번호로
qs = sorted(set(ta) & set(tb))
d1 = sorted(tb[q][6] - ta[q][4] for q in qs)   # A 보냄 → B 도착 (+off)
d2 = sorted(ta[q][6] - tb[q][4] for q in qs)   # B 보냄 → A 도착 (−off)
if off_ab is None:
    off_ab = (p(d1, 0.05) - p(d2, 0.05)) / 2
lat = (p(d1, 0.05) - off_ab + p(d2, 0.05) + off_ab) / 2
lat_ab = p(d1, 0.05) - off_ab; lat_ba = p(d2, 0.05) + off_ab
print(f"한 방향(5 백분위): A→B {lat_ab:.1f} us(B 가 늦으면 B 의 보냄에 묶여 크게 보임), B→A {lat_ba:.1f} us")
print(f"정렬: 노드 안 (커널−호스트) A {nodes['a']['off_k']:.1f} us, B {nodes['b']['off_k']:.1f} us  | AR 번호 차 B−A {shift}, "
      f"노드 사이 시계 B−A {off_ab:.1f} us, 한 방향 지연(5 백분위) {lat:.1f} us")

# 공통 시간축(A 의 호스트 시계, us)
def kt(n, t):   # 커널 시각 → A 호스트 시계
    t = t - nodes[n]['off_k']
    return t - off_ab if n == 'b' else t
def ht(n, t):   # 호스트 시각 → A 호스트 시계
    return t - off_ab if n == 'b' else t

# ---- 토큰당 명세(디코드 AR 구간만) ----
spec = {}
for n in 'ab':
    N = nodes[n]; K = N['K']; tl = N['tl']; cat = N['cat']
    # 디코드 구간: 타임라인 첫 AR 의 보냄 ~ 마지막 AR 의 보냄(호스트), 커널 시계로 바꿔 자름
    t0 = tl[0][4] + N['off_k']; t1 = tl[-1][4] + N['off_k']
    land = [r[6] + N['off_k'] for r in tl]
    acc = collections.defaultdict(float); cnt = collections.defaultdict(int)
    prev_end = None
    for i, k in enumerate(K):
        if k[0] < t0 or k[0] > t1:
            continue
        c = cat[i] or 'F 그 밖'
        if c.startswith('X'):
            # wait_add: land 전까지는 상대 기다림, 뒤는 더하기·해제
            j = bisect.bisect_left(land, k[0] - 1)
            lj = land[j] if j < len(land) else k[1]
            w = max(0.0, min(k[1], lj) - k[0])
            acc['X1 상대 기다림(받기 커널 안)'] += w; acc['X2 더하기·해제'] += (k[1] - k[0]) - w
            cnt['X1 상대 기다림(받기 커널 안)'] += 1
        else:
            acc[c] += k[1] - k[0]; cnt[c] += 1
        if prev_end is not None and k[0] > prev_end:
            acc['Z 커널 사이 빈틈(GPU 쉼)'] += k[0] - prev_end
        prev_end = max(prev_end or k[1], k[1])
    ntok = len(tl) / 96
    total = t1 - t0
    spec[n] = (acc, cnt, ntok, total)
    # 호스트 쪽(타임라인): AR 마다 구간
    h = collections.defaultdict(float)
    for a, b in zip(tl[:-1], tl[1:]):
        h['h1 다음 명령 받기·커널 발행(end→entry)'] += b[1] - a[5]
        h['h2 직전 받기 끝 기다림(entry→pending)'] += b[2] - b[1]
        h['h3 부분합 기다림(pending→ready)'] += b[3] - b[2]
        h['h4 보내기 복사·post(ready→sent)'] += b[4] - b[3]
        h['h5 받기 커널 발행·넘김(sent→end)'] += b[5] - b[4]
    spec[n] = (acc, cnt, ntok, total, h)

print(f"\n토큰당 명세 (디코드 AR {len(nodes['a']['tl'])}개 ≈ 토큰 {spec['a'][2]:.1f}개, AR 주기 평균 A {spec['a'][3]/len(nodes['a']['tl']):.1f} us)")
keys = sorted(set(spec['a'][0]) | set(spec['b'][0]))
print(f"{'GPU 구분':34s} {'A ms/토큰':>9s} {'B ms/토큰':>9s} {'A 커널/토큰':>10s}")
for c in keys:
    va = spec['a'][0][c] / spec['a'][2] / 1e3; vb = spec['b'][0][c] / spec['b'][2] / 1e3
    print(f"{c:34s} {va:9.2f} {vb:9.2f} {spec['a'][1][c] / spec['a'][2]:10.0f}")
print(f"{'합(구간 길이)':34s} {spec['a'][3]/spec['a'][2]/1e3:9.2f} {spec['b'][3]/spec['b'][2]/1e3:9.2f}")
print(f"\n{'호스트 구분(rpc-server 주 스레드)':34s} {'A ms/토큰':>9s} {'B ms/토큰':>9s}")
for c in sorted(spec['a'][4]):
    print(f"{c:34s} {spec['a'][4][c]/spec['a'][2]/1e3:9.2f} {spec['b'][4][c]/spec['b'][2]/1e3:9.2f}")

# ---- 시간 순서: 가운데 AR nseq 개 ----
tl_a = nodes['a']['tl']; mid = len(tl_a) // 2
# 프로파일러 아래에서는 호스트 발행이 가끔 크게 늦는다: 가운데부터 찾아, AR nseq+1 개 연속으로 A 주기 < 450 us·발행(end→entry) < 150 us 인 구간
def calm(i, cyc, gap):
    return all(0 < i + j < len(tl_a) and tl_a[i + j][4] - tl_a[i + j - 1][4] < cyc and tl_a[i + j][1] - tl_a[i + j - 1][5] < gap
               for j in range(0, nseq + 2))
order = sorted(range(1, len(tl_a) - nseq - 2), key=lambda i: abs(i - mid))
i0 = next((i for cyc, gap in ((450, 150), (550, 250), (700, 400)) for i in order if calm(i, cyc, gap)), mid)
q0 = tl_a[i0][0]; q1 = q0 + nseq
print(f"\n고른 구간의 A AR 주기(us): {[tl_a[i0 + j][4] - tl_a[i0 + j - 1][4] for j in range(0, nseq + 2)]}")
start = ht('a', ta[q0][5])                       # A 가 AR q0 에서 돌아온 시각을 0 으로
stop = ht('a', ta[q1][5]) if q1 in ta else start + 2000
print(f"\n시간 순서: AR {q0}–{q1} (0 = A 가 AR {q0} 에서 돌아온 시각, us)")
events = []
for n in 'ab':
    N = nodes[n]
    for q in range(q0, q1 + 1):
        r = (ta if n == 'a' else tb).get(q)
        if r:
            events.append((ht(n, r[3]) - start, n, f'부분합 준비(호스트 확인) AR{q}'))
            events.append((ht(n, r[4]) - start, n, f'보냄 AR{q}'))
            events.append((ht(n, r[6]) - start, n, f'상대 것 도착 AR{q}'))
    blocks = []
    for i, k in enumerate(N['K']):
        s, e = kt(n, k[0]) - start, kt(n, k[1]) - start
        if e < 0 or s > stop - start:
            continue
        c = (N['cat'][i] or 'F 그 밖')
        if blocks and blocks[-1][2] == c and s - blocks[-1][1] < 6:
            blocks[-1][1] = e; blocks[-1][3] += 1; blocks[-1][4].append(short(k[2]))
        else:
            blocks.append([s, e, c, 1, [short(k[2])]])
    N['blocks'] = blocks
    print(f"-- 노드 {n.upper()} GPU")
    for s, e, c, cntk, names in blocks:
        top = collections.Counter(names).most_common(2)
        print(f"  {s:8.1f} – {e:8.1f}  ({e-s:6.1f})  {c:30s} 커널 {cntk:3d}  {', '.join(f'{x}×{y}' for x, y in top)}")
print("-- 호스트·통신 사건")
for t, n, what in sorted(events):
    if -50 < t < stop - start + 50:
        print(f"  {t:8.1f}  {n.upper()}  {what}")

if svg:
    colors = {'A': '#3b82f6', 'B': '#f59e0b', 'C': '#fbbf24', 'D': '#a855f7', 'E': '#10b981', 'F': '#9ca3af', 'X': '#ef4444', 'Y': '#f97316'}
    W = 1400; span = stop - start; sx = lambda t: 120 + (t / span) * (W - 140)
    out = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="260" font-family="sans-serif" font-size="11">']
    for row, n in enumerate('ab'):
        y = 40 + row * 90
        out.append(f'<text x="10" y="{y+18}">노드 {n.upper()} GPU</text>')
        for s, e, c, cntk, names in nodes[n]['blocks']:
            out.append(f'<rect x="{sx(max(0,s)):.1f}" y="{y}" width="{max(0.8, sx(e)-sx(max(0,s))):.1f}" height="28" fill="{colors.get(c[0], "#999")}"><title>{c} {e-s:.1f} us, 커널 {cntk}</title></rect>')
        for t, nn, what in events:
            if nn == n and 0 <= t <= span:
                col = '#111' if what.startswith('보냄') else '#dc2626' if what.startswith('상대') else '#6b7280'
                out.append(f'<line x1="{sx(t):.1f}" y1="{y-6}" x2="{sx(t):.1f}" y2="{y+34}" stroke="{col}" stroke-width="1"><title>{what} {t:.1f} us</title></line>')
    lx = 120
    for k, v in [('A', '나뉘는 행렬곱'), ('B', 'hc 행렬곱'), ('C', 'hc 작은'), ('D', '라우터·MoE'), ('E', 'GDN·attn 작은'), ('X', '받기(대기+더하기)'), ('Y', '보내기 복사')]:
        out.append(f'<rect x="{lx}" y="225" width="12" height="12" fill="{colors[k]}"/><text x="{lx+16}" y="235">{k} {v}</text>'); lx += 150
    out.append(f'<text x="120" y="20">AR {q0}–{q1}, 0 – {span:.0f} us (세로선: 검정 보냄, 빨강 상대 것 도착, 회색 부분합 준비)</text></svg>')
    open(svg, 'w').write('\n'.join(out))
    print(f"\nsvg: {svg}")
