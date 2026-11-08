# sched_times 줄(GGML_SCHED_TIMES)에서 메타 부분그래프(split 1) 입력 복사 시간 중앙값: python3 -I stsum.py <sched_times.txt>...
import sys, re, statistics as st, collections
for f in sys.argv[1:]:
    per = collections.defaultdict(list); launch = []; tot = []
    for l in open(f):
        if "split 1" not in l:
            continue
        m = re.search(r"\+(\d+) (\d+)us", l); launch.append(int(m.group(1)))
        s = 0
        for k, p in enumerate(l.split("|")[1:]):
            m = re.match(r" s1 (.*) (\d+)B \+(\d+) (\d+)us", p.strip() and " " + p.strip())
            if m:
                per[(k, m.group(1))].append(int(m.group(4))); s += int(m.group(4))
        tot.append(s)
    print(f"{f.rsplit('/', 1)[-1]}: n={len(launch)} meta launch at +{st.median(launch):.0f} us (median), input copies sum {st.median(tot):.0f} us")
    print("   " + " ".join(f"{n}:{st.median(v):.0f}" for (k, n), v in sorted(per.items())))
