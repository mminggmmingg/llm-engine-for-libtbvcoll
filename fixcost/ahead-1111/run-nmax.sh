#!/usr/bin/env bash
# 11-11 10:0x: 초안 길이 다시(지금 빌드 — 초안 96k qmix, 4토큰 묶음, r2): n-max 2 / 3(기본) / 4, 번갈아 2바퀴
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; O=$R/fixcost/ahead-1111
export BENCH_S=600 WATCH=0
export SE_n2="-devd ROCm0 --spec-draft-n-max 2" SE_n4="-devd ROCm0 --spec-draft-n-max 4"
OUTDIR=ahead-1111 RUNS="${RUNS:-mtp:n4 mtp:def mtp:n2 mtp:n4 mtp:def mtp:n2}" bash $R/tools/bench/node-ab.sh
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1t $O/srv-2node-*-bench.txt | head -6)
for d in $(ls -td $R/runs/srv-2node-mtp-bs-n[24]-* $R/runs/srv-2node-mtp-bs-def-* | head -6); do python3 -c "
import json; n=a=0; k=0
for l in open('$d/results.jsonl'):
    j=json.loads(l); n+=j['draft_n']; a+=j['draft_acc']
print('$d'.split('/')[-1], n, a, round(a/n,3))"; done
