#!/usr/bin/env bash
# 11-09 아침: 기본 MAX_TOKENS=4 로 바꾼 빌드 확인 — MTP 기본(감시기 회 포함), m1(예전 기본 1), none 기본
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll
O=$R/fixcost/fuse2-1108
export SA_m1="GGML_CUDA_COMM_OUT_MAX_TOKENS=1" SB_m1="GGML_CUDA_COMM_OUT_MAX_TOKENS=1"
cd $O
OUTDIR=fuse2-1108 RUNS="mtp:new mtp:m1" bash $R/tools/bench/node-ab.sh
WATCH=0 OUTDIR=fuse2-1108 RUNS="none:new" bash $R/tools/bench/node-ab.sh
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1t $O/srv-2node-*-bs-new*-bench.txt $O/srv-2node-*-bs-m1*-bench.txt)
