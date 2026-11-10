#!/usr/bin/env bash
# 11-11: 4토큰 묶음(GLU·conv-norm) 새 바이너리(new) vs 예전(old, 11-09 22:42) — MTP 3쌍 + none 1쌍 번갈아, 구성마다 감시기·DRAM 회. r2 기본(srv-probe).
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll
export BIN_old=/data/parksThink/macos_reversing/codex/zbook-rdma/experiments/engine2n/llama.cpp/build-rocm3/bin-1109-2242 BENCH_S=600
OUTDIR=ntok-1111 RUNS="mtp:new mtp:old mtp:new mtp:old mtp:new mtp:old none:new none:old" bash $R/tools/bench/node-ab.sh
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1t $R/fixcost/ntok-1111/srv-2node-*-bench.txt)
