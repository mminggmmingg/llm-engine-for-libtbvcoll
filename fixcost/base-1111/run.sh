#!/usr/bin/env bash
# 11-11 03:4x: 밤샘 작업 뒤 아침 기준값 — 지금 기본(새 바이너리: 4토큰 묶음, MTP 회 r2, prefetch 16 MB) none 2 · MTP 2 + 감시기·DRAM
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll
export BENCH_S=600
OUTDIR=base-1111 RUNS="none:def mtp:def none:def mtp:def" bash $R/tools/bench/node-ab.sh
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1t $R/fixcost/base-1111/srv-2node-*-bench.txt)
