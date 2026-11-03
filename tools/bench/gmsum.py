# gpumetrics_ts.py 출력 요약(GPU 활동 50% 이상인 줄만): gmsum.py <gm.txt>
#   gfx 클럭·상한, 활동, 소켓·gfx·코어 전력, 코어 상한, (있으면) fclk·uclk·DRAM 읽기·쓰기(p10/p50/p90), 그 구간의 스로틀 카운터 증가(spl fppt sppt thm_core)
import sys
rows = []
for l in open(sys.argv[1]):
    f = l.split()
    if len(f) < 19:
        continue
    try:
        v = [float(x) for x in f]
    except ValueError:
        continue
    if v[3] >= 50:
        rows.append(v)
if not rows:
    print('no busy rows'); sys.exit(0)
def q(i):
    s = sorted(r[i] for r in rows); n = len(s)
    return f"{s[n//10]:.0f}/{s[n//2]:.0f}/{s[n*9//10]:.0f}"
thr = lambda i: int(rows[-1][i] - rows[0][i])
ext = f"fclk {q(20)} uclk {q(21)} dramR {q(22)} dramW {q(23)} " if all(len(r) >= 24 for r in rows) else ""
print(f"n={len(rows)} gfx {q(1)} 상한 {q(2)} 활동 {q(3)} 소켓W {q(4)} gfxW {q(5)} 코어W {q(6)} 코어상한 {q(7)} {ext}"
      f"| 스로틀증가 spl {thr(13)} fppt {thr(14)} sppt {thr(15)} thm_core {thr(16)}")
