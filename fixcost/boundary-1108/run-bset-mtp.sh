#!/usr/bin/env bash
# 11-08 밤: 입력끼리만 묶기(bs) MTP 3바퀴 + 감시기 회
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll
O=$R/fixcost/boundary-1108
export CL_bs="GGML_RPC_BATCH_MAX=65536 GGML_RPC_BATCH_SET_ONLY=1"
cd $O
WATCH=1 OUTDIR=boundary-1108 RUNS="mtp:bs mtp:def mtp:bs mtp:def mtp:bs mtp:def" bash $R/tools/bench/node-ab.sh
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1t $O/srv-2node-mtp-bs-bs*-bench.txt)
