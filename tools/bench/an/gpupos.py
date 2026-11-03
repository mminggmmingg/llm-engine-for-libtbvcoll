# inferwatch 세션의 a.ring/b.ring: 기록 링의 GPU 도장(type 4)으로 단계 안 위치별 부분그래프 계산(앞 AR 더하기 끝 → 이 AR 복사 시작), 복사 끝 → 기다림 시작, 기다림 시간 중앙값
import struct, sys, statistics as st, collections
def recs(p):
    # inferwatch 세션 파일: 링 머리 4096 B, 첫 기록 번호 u64, 이어진 64 B 기록
    b = open(p, 'rb').read()
    frm = struct.unpack_from('<Q', b, 4096)[0]
    out = []
    n = (len(b) - 4104) // 64
    for k in range(n):
        o = 4104 + k * 64
        idx, typ, a, bb = struct.unpack_from('<IIII', b, o)
        if idx != ((frm + k + 1) & 0xffffffff): continue
        out.append((typ, a, bb, struct.unpack_from('<6q', b, o + 16)))
    return out
def gpu(p):
    g = {}
    for typ, a, bb, t in recs(p):
        if typ == 4: g[a] = t[:5]
    return g
if __name__ == '__main__':
    for p in sys.argv[1:]:
        g = gpu(p); s = sorted(g)
        rows = []  # (seq, compute us, out->wait start us, wait us)
        for q in s:
            if q - 1 in g:
                c = (g[q][0] - g[q-1][4]) / 100.0      # 100 MHz ticks → us
                rows.append((q, c, (g[q][2] - g[q][1]) / 100.0, (g[q][3] - g[q][2]) / 100.0, (g[q][4]-g[q][3])/100.0, (g[q][1]-g[q][0])/100.0))
        pos = {}; cur = None
        for q, c, *_ in rows:
            if c > 1000: cur = 0
            elif cur is not None: cur += 1
            pos[q] = cur
        by = collections.defaultdict(list)
        for r in rows:
            k = pos[r[0]]
            if k is None or k == 0 or k >= 96: continue
            kind = 'attn' if k % 8 == 6 else ('gdn' if k % 2 == 0 else 'moe')
            if k == 2: kind = 'layer0'
            by[kind].append(r)
        print(p)
        tot = 0
        for kind in ('moe', 'gdn', 'attn', 'layer0'):
            v = by[kind]
            if not v: continue
            n = len(v) / max(1, sum(1 for q in pos.values() if q == 1))
            print(f'  {kind:6s} x{n:4.1f}/step  compute {st.median(x[1] for x in v):7.1f}  out {st.median(x[5] for x in v):5.1f}  out->wait {st.median(x[2] for x in v):6.1f}  wait {st.median(x[3] for x in v):6.1f}  add {st.median(x[4] for x in v):5.1f}  (mean compute {st.mean(x[1] for x in v):7.1f})')
