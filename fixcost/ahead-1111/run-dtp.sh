#!/usr/bin/env bash
# 11-11 08:5x: 초안 동안 노는 B 를 쓰기 — 초안을 2노드 TP 로(-devd 없이, 본 모델과 같은 meta). 11-05(전체 어휘 초안)엔 같았음, 지금은 qmix 96k
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; O=$R/fixcost/ahead-1111
export BENCH_S=600 WATCH=0 SE_dtp=""
OUTDIR=ahead-1111 RUNS="${RUNS:-mtp:dtp mtp:def}" bash $R/tools/bench/node-ab.sh
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1t $O/srv-2node-*-bench.txt | head -2)
