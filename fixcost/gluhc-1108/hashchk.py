# bench.txt 들의 해시가 기준(11-08 새벽 r4 기본 빌드)과 같은지: python3 -I hashchk.py <bench.txt>...
import json, sys
REF = {"prose": "c400cbc159a92385", "code": "40b4288f0dd4a627", "ko": "572e7e41bbc125c8",
       "math": "412ba5ed1b079548", "json": "e5be2acea31788a9", "summary": "d67a87d3bd74f8dc"}
for f in sys.argv[1:]:
    rows = [json.loads(l) for l in open(f) if l.startswith("{")]
    bad = [r["id"] for r in rows if REF.get(r["id"]) != r["sha"]]
    print(f"{f.rsplit('/', 1)[-1]}: {len(rows) - len(bad)}/{len(rows)} same" + (f" DIFF {bad}" if bad else ""))
