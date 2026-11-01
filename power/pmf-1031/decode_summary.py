# gpu_metrics 시계열에서 GPU 활동 > 40% 인 구간(디코드)만 중앙값/사분위
import sys, statistics as st
rows = [l.split() for l in open(sys.argv[1]) if l.strip() and l[0] != '#']
sel = [r for r in rows if len(r) > 18 and int(r[3]) > 40]
if not sel: print('no busy rows'); sys.exit()
q = lambda k: sorted(float(r[k]) for r in sel)
def f(k):
    v = q(k); n = len(v); return f"{v[n//4]:.0f}/{v[n//2]:.0f}/{v[3*n//4]:.0f}"
d = lambda k: int(sel[-1][k]) - int(sel[0][k])
print(f"n={len(sel)} gfx {f(1)} 상한 {f(2)} 활동 {f(3)} 소켓W {f(4)} gfxW {f(5)} 코어W {f(6)} 코어상한 {f(7)} | 스로틀증가 spl {d(13)} fppt {d(14)} sppt {d(15)} thm_core {d(16)}")
