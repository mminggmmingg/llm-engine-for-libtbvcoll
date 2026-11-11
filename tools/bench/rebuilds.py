#!/usr/bin/env python3
# 감시기 세션의 클라이언트 기록(client.ring)에서 본 모델(서버로 명령이 나가는) ubatch 중 그래프를 다시 지은 것을 세고 그 비용을 잰다(2026-11-11).
#   python3 tools/bench/rebuilds.py runs/watch/<세션> [...]
# UBATCH 기록(a = 토큰 수, b = 그래프 재사용 1/0, t = 시작·그래프 준비·입력·계산 발행) 중 시작~발행 사이에 명령(CCMD)을 보낸 것만 본 모델로 본다
# (초안 컨텍스트는 클라이언트 GPU 라 명령이 없다). 다시 지은 것: 그래프 준비 시간, 발행까지 시간, 그 안의 GRAPH_COMPUTE 간격.
import sys, struct, bisect
from statistics import median


def load(path):
    b = open(path, 'rb').read()
    assert b[0:8] == b'GGRPCTR1'
    frm, = struct.unpack_from('<Q', b, 4096)
    recs = []
    for k in range((len(b) - 4104) // 64):
        o = 4104 + k * 64
        idx, typ, a, bb = struct.unpack_from('<IIII', b, o)
        if idx != ((frm + k + 1) & 0xffffffff):
            continue
        recs.append((typ, a, bb, struct.unpack_from('<6q', b, o + 16)))
    return recs


UBATCH, CCMD, GRAPH_COMPUTE = 10, 7, 10
for sess in sys.argv[1:]:
    recs = load(sess.rstrip('/') + '/client.ring')
    ubs = sorted([r for r in recs if r[0] == UBATCH], key=lambda r: r[3][0])
    cmds = sorted([r for r in recs if r[0] == CCMD], key=lambda r: r[3][0])
    cq = [c[3][0] for c in cmds]
    tgt = []
    for u in ubs:
        t0, t1, t3 = u[3][0], u[3][1], u[3][3]
        i0, i1 = bisect.bisect_left(cq, t0), bisect.bisect_right(cq, t3 + 5)
        if i1 > i0:
            gr = [c[3][0] for c in cmds[i0:i1] if c[1] == GRAPH_COMPUTE]
            gaps = sorted(gr[k + 1] - gr[k] for k in range(len(gr) - 1))
            tgt.append(dict(ntok=u[1], reused=u[2], ready=t1 - t0, launched=t3 - t0, ngraph=len(gr),
                            gap=gaps[len(gaps) // 2] if gaps else 0))
    dec = [t for t in tgt if t['ntok'] <= 8]
    re = [t for t in dec if t['reused'] == 0]
    ok = [t for t in dec if t['reused'] == 1]
    print(f"{sess}: 본 모델 ubatch {len(tgt)} (decode 크기 {len(dec)}: 다시 지음 {len(re)}, 재사용 {len(ok)})")
    if re:
        print(f"  다시 지음: 그래프 준비 중앙 {median(t['ready'] for t in re)/1e3:.1f} ms, 발행까지 중앙 {median(t['launched'] for t in re)/1e3:.1f} ms"
              f" (최대 {max(t['launched'] for t in re)/1e3:.1f}), 합 {sum(t['launched'] for t in re)/1e6:.2f} s,"
              f" GRAPH_COMPUTE 간격 중앙 {median(t['gap'] for t in re if t['gap']):.0f} us; 크기 {sorted(t['ntok'] for t in re)}")
    if ok:
        print(f"  재사용: 발행까지 중앙 {median(t['launched'] for t in ok)/1e3:.2f} ms")
