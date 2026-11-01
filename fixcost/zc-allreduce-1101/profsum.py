# comm_prof 블록 평균(디코드 블록만: avg wire 가 최솟값인 블록): profsum.py <prof-a.txt> <prof-b.txt>
import re, sys, statistics as st
def load(p):
    rows = []; cur = None
    for l in open(p):
        m = re.search(r'gap ([\d.]+) sync ([\d.]+) d2h [\d.]+ net ([\d.]+) h2d\+add ([\d.]+) \| avg wire (\d+)', l)
        if m:
            cur = dict(gap=float(m[1]), sync=float(m[2]), net=float(m[3]), h2d=float(m[4]), wire=int(m[5]), pw=None); rows.append(cur); continue
        m = re.search(r'peer.s landed avg ([\d.]+)', l)
        if m and cur is not None: cur['pw'] = float(m[1])
    w = min(r['wire'] for r in rows)
    return [r for r in rows if r['wire'] == w and r['pw'] is not None]
for p in sys.argv[1:]:
    r = load(p)
    f = lambda k: st.mean(x[k] for x in r)
    print(f"{p.split('/')[-1][:48]:48s} n={len(r):3d} gap {f('gap'):6.1f} sync {f('sync'):6.1f} net {f('net'):5.1f} h2d {f('h2d'):4.1f} cycle {f('gap')+f('sync')+f('net')+f('h2d'):6.1f} | sent->landed {f('pw'):5.1f} (med {st.median(x['pw'] for x in r):5.1f})")
