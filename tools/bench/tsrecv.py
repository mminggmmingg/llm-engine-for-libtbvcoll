# 2노드 AR 주기 영수증(프로파일러 없이): tsrecv.py <runs/tl2node-... 폴더>
#   서버를 GGML_CUDA_COMM_TS=1 + GGML_RPC_COMM_PROF_TL 로 돌린 기록(tl2node.sh, SRVX)에서 노드마다 AR 한 주기를 GPU 시계로 나눈다.
#   tl.txt 열: seq entry pending ready sent end land rc0 rc1 g0..g4 (호스트 us, GPU tick), tl.txt.cal: (호스트 us, GPU tick) 쌍.
#   g0 복사 시작(= 부분그래프 끝) g1 복사 끝 g2 기다림 커널 시작 g3 상대 부분합 도착 확인 g4 더하기 끝.
#   구간(AR q 기준, 다음 AR 은 q+1):
#     sub   = g0[q+1] - g4[q]  부분그래프(커널 실행 + 커널 사이 빈틈 + 발행이 늦어 쉰 시간)
#     copy  = g1 - g0          부분합을 호스트 메모리로
#     host  = g2 - g1          GPU 쉼: 호스트가 동기화에서 깨어나 보내고 기다림 커널을 넣을 때까지
#     peer  = g3 - g2          GPU 쉼: 상대 부분합이 올 때까지
#     add   = g4 - g3
#   발행: 다음 부분그래프의 GRAPH_RECOMPUTE(rc0..rc1, 호스트)와 GPU 를 비교 — starve = max(0, rc0[q+1] - g4[q]) 는 더하기가 끝났는데
#   호스트가 아직 다음 커널을 내기 시작하지 않은 시간(첫 커널은 rc0 뒤에야 들어감; 아래한계), late = rc1[q+1] - g0[q+1] > 0 이면 발행이
#   부분그래프 끝보다 늦게 끝남(발행에 묶임).
import sys, os, re, statistics as st

def load(d):
    rows = []
    for l in open(os.path.join(d, 'tl.txt')):
        v = l.split()
        if len(v) < 14:
            continue
        r = [int(x) for x in v]
        rows.append(r)
    cal = [tuple(int(x) for x in l.split()) for l in open(os.path.join(d, 'tl.txt.cal'))]
    return rows, cal

def conv(cal):
    # GPU tick -> 호스트 us: 맞춤 쌍 사이를 선으로 잇는다(호스트 시계가 NTP 로 미끄러지면 기울기가 바뀜 — 재부팅 직후 A).
    # 첫·끝 쌍 밖의 tick 은 None(교차 구간을 믿을 수 없음)
    cal = sorted(cal, key=lambda c: c[1])
    xs = [c[1] for c in cal]; ys = [c[0] for c in cal]
    sl = [(ys[i + 1] - ys[i]) / (xs[i + 1] - xs[i]) for i in range(len(cal) - 1)]
    def f(t):
        if t < xs[0] or t > xs[-1]:
            return None
        i = 0
        while i < len(sl) - 1 and t > xs[i + 1]:
            i += 1
        return ys[i] + sl[i] * (t - xs[i])
    return f, sl

def pct(v, p):
    v = sorted(v)
    return v[min(len(v) - 1, int(p / 100 * len(v)))]

def node(d, name):
    rows, cal = load(d)
    g, sl = conv(cal)
    by = {r[0]: r for r in rows}
    seqs = sorted(by)
    out = []
    for q in seqs:
        n = by.get(q + 1)
        r = by[q]
        if n is None or 0 in r[9:14] or 0 in n[9:14] or n[7] == 0:
            continue
        G = [g(t) for t in r[9:14]]
        Gn = [g(t) for t in n[9:14]]
        if None in G or None in Gn:
            continue
        e = dict(q=q,
                 cyc=Gn[0] - G[0],
                 sub=Gn[0] - G[4], copy=G[1] - G[0], host=G[2] - G[1], peer=G[3] - G[2], add=G[4] - G[3],
                 wake=r[3] - G[1],            # 호스트 동기화가 돌아온 시각 - 복사 끝
                 send=r[4] - r[3],            # 보내기
                 enq=G[2] - r[4],             # 보낸 뒤 기다림 커널 시작까지
                 starve=max(0.0, n[7] - G[4]), late=n[8] - Gn[0], rc=n[8] - n[7],
                 land_gpu=G[3] - r[6] if r[6] else None)  # 도우미 스레드가 받은 뒤 GPU 가 보기까지
        out.append(e)
    print(f"== {name}: AR {len(out)}개(맞춤 쌍 사이), 시계 맞춤 {len(cal)}쌍, 구간 기울기 us/100tick " + " ".join(f"{x*100:.6f}" for x in sl))
    return out

def summary(name, es):
    keys = ['cyc', 'sub', 'copy', 'host', 'peer', 'add', 'wake', 'send', 'enq', 'starve', 'late', 'rc']
    # 디코드 정상 구간: 주기 상위 1% 는 토큰 경계·이상치로 따로 셈
    # 토큰 경계: 주기 1 ms 넘는 AR(토큰마다 하나) 은 따로
    norm = [e for e in es if e['cyc'] <= 1000]
    big = [e for e in es if e['cyc'] > 1000]
    print(f"-- {name}: 보통 AR {len(norm)}개, 1 ms 넘는 AR {len(big)}개(간격 중앙 {st.median([b2['q'] - b1['q'] for b1, b2 in zip(big, big[1:])]) if len(big) > 1 else 0} AR)")
    if big:
        print("   경계 AR: " + "  ".join(f"{k} {st.median(e[k] for e in big):.0f}" for k in ('cyc', 'sub', 'host', 'peer', 'starve', 'rc')) + "  (중앙, us)")
    print("   " + "".join(k.rjust(9) for k in keys))
    for lab, f in (('mean', st.mean), ('p10', lambda v: pct(v, 10)), ('med', st.median), ('p90', lambda v: pct(v, 90))):
        print(lab.ljust(5) + "".join(f"{f([e[k] for e in norm]):9.1f}" for k in keys))
    m = lambda k: st.mean(e[k] for e in norm)
    tot = m('cyc')
    print(f"   몫: sub {m('sub')/tot*100:.1f}%  copy {m('copy')/tot*100:.1f}%  host {m('host')/tot*100:.1f}%  peer {m('peer')/tot*100:.1f}%  add {m('add')/tot*100:.1f}%")
    print(f"   발행: 다음 커널 발행 시작이 더하기 끝보다 늦은 AR {sum(1 for e in norm if e['starve'] > 0)}개 (평균 {m('starve'):.1f} us),"
          f" 발행이 부분그래프 끝보다 늦게 끝난 AR {sum(1 for e in norm if e['late'] > 0)}개")
    return norm

if __name__ == '__main__':
    d = sys.argv[1]
    res = {}
    for n in ('a', 'b'):
        p = os.path.join(d, n)
        if os.path.exists(os.path.join(p, 'tl.txt.cal')):
            res[n] = summary(n.upper(), node(p, n.upper()))
    # 토큰당(AR 96개)
    for n, es in res.items():
        k = 96 / 1000
        print(f"{n.upper()} 토큰당 ms(×96): " + "  ".join(f"{x} {st.mean(e[x] for e in es)*k:.2f}" for x in ('cyc', 'sub', 'copy', 'host', 'peer', 'add')))
