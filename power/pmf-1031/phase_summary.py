# 단계별 요약: pfload 출력(GB/s)과 gpu_metrics 시계열을 단계 구간으로 묶어 중앙값
import sys, statistics as st
pf, gm = sys.argv[1], sys.argv[2]
rows = [l.split() for l in open(gm) if l.strip() and not l.startswith('#')]
ph = {}
for l in open(pf):
    p = l.split()
    if len(p) >= 4 and p[2] != '': ph.setdefault(p[1], []).append(float(p[2]))
names = ['gpu', 'gpu+spin1', 'gpu+spin2', 'gpu(2)', 'spin1']
# gpumetrics 는 pfload 보다 1초 먼저 시작, hip 초기화 ≈1–2초: 단계 경계는 pfload 의 첫 출력 시각 기준
pts = [(float(l.split()[0]), l.split()[1]) for l in open(pf) if len(l.split()) >= 4]
seq = []; prev = None
for t, n in pts:
    if n != prev: seq.append([n, t, t]); prev = n
    else: seq[-1][2] = t
init = pts[0][0] - 1.0  # 첫 출력은 단계 시작 1초 뒤
off = 1.0 + 0  # gpumetrics 시작이 pfload 시작보다 1초 이름(실제 hip 초기화 시간은 init 에 포함 안 됨)
print(f"{'단계':<11}{'GB/s':>6}{'gfx MHz':>9}{'gfx상한':>8}{'활동%':>6}{'소켓W':>7}{'gfxW':>6}{'코어W':>6}{'코어상한':>9}  스로틀증가(spl fppt sppt thm_core)")
for i, (n, ta, tb) in enumerate(seq):
    lo, hi = ta - 1.0 + 2.0, tb   # 단계 시작 2초 뒤부터(전환 제외)
    # pfload t 는 pfload 의 t0(=hip 초기화 뒤) 기준 → gm 기준으로 바꾸려면 gm 시작~pfload t0 사이 차이 필요: 첫 GPU 활동 시각으로 맞춤
    seq[i] += [lo, hi]
# gm 에서 첫 GPU 활동(활동% > 30) 시각 = pfload t0 근처
g0 = next(float(r[0]) for r in rows if int(r[3]) > 30)
for n, ta, tb, lo, hi in seq:
    sel = [r for r in rows if lo + g0 <= float(r[0]) <= hi + g0]
    if not sel: continue
    med = lambda k, f=float: st.median(f(r[k]) for r in sel)
    d = lambda k: int(sel[-1][k]) - int(sel[0][k])
    gb = st.median(ph.get(n, [0])) if n in ph else 0
    print(f"{n:<11}{st.median([float(l.split()[2]) for l in open(pf) if len(l.split())>=4 and l.split()[1]==n and lo<=float(l.split()[0])<=hi] or [0]):>6.0f}{med(1):>9.0f}{med(2):>8.0f}{med(3):>6.0f}{med(4):>7.1f}{med(5):>6.1f}{med(6):>6.1f}{med(7):>9.0f}  {d(13)} {d(14)} {d(15)} {d(16)}")
