# bench.txt 들의 해시가 기준과 같은지: python3 -I hashchk.py <bench.txt>...
# 기준(2026-11-12 부터): LLAMA_QSA_SHORT=1 기본 빌드. 그래프 모양이 none(1토큰)과 MTP(검증 4토큰)에서 다르게 바뀌어 두 모드의 출력이 서로 다르다 → 모드별 기준.
#   모드는 파일 이름(srv-<topo>-<mode>-...)에서 읽는다. 이전 기준(11-08 새벽 r4 기본 빌드, none·MTP 같음)은 HASHREF=1108 — LLAMA_QSA_SHORT=0 이면 지금도 그대로 나온다.
import json, os, re, sys
REF_1108 = {"prose": "c400cbc159a92385", "code": "40b4288f0dd4a627", "ko": "572e7e41bbc125c8",
            "math": "412ba5ed1b079548", "json": "e5be2acea31788a9", "summary": "d67a87d3bd74f8dc"}
REF_1112 = {
    "none": {"prose": "6c15968891060e1e", "code": "ce5ae3194184c39e", "ko": "ecfc023e79d80562",
             "math": "810ea29e45d4e955", "json": "a27f064f4b47b01f", "summary": "e0ee1132bffdb4f3"},
    "mtp":  {"prose": "d289912e310c23de", "code": "344aa83baeddc2a6", "ko": "5942d0aeddf8e42a",
             "math": "412ba5ed1b079548", "json": "a27f064f4b47b01f", "summary": "e0ee1132bffdb4f3"},
}
old = os.environ.get("HASHREF") == "1108"
for f in sys.argv[1:]:
    name = f.rsplit('/', 1)[-1]
    m = re.match(r"srv-[^-]+-(none|mtp)-", name)
    mode = m.group(1) if m else None
    if old:
        ref, tag = REF_1108, "ref 1108"
    elif mode:
        ref, tag = REF_1112[mode], f"ref 1112 {mode}"
    else:
        print(f"{name}: mode not in file name (srv-<topo>-<none|mtp>-...)"); continue
    rows = [json.loads(l) for l in open(f) if l.startswith("{")]
    bad = [r["id"] for r in rows if ref.get(r["id"]) != r["sha"]]
    print(f"{name}: {len(rows) - len(bad)}/{len(rows)} same ({tag})" + (f" DIFF {bad}" if bad else ""))
