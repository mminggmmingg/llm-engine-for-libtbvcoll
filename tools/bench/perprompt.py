# 실행별 프롬프트별 tok/s 표: perprompt.py <bench.txt>...  (spec_bench 출력의 json 줄)
import json, sys, os
runs = []
for p in sys.argv[1:]:
    d = {}
    for l in open(p):
        l = l.strip()
        if l.startswith('{'):
            j = json.loads(l); d[j['id']] = (j['tps'], j['n'], j.get('sha', '')[:6])
    runs.append((os.path.basename(p).replace('srv-2node-', '').replace('-bench.txt', ''), d))
ids = list(runs[0][1].keys())
print('run'.ljust(34) + ''.join(i.rjust(16) for i in ids))
for name, d in runs:
    print(name.ljust(34) + ''.join((f"{d[i][0]:6.2f}/{d[i][1]:3d}/{d[i][2]}" if i in d else '-').rjust(16) for i in ids))
