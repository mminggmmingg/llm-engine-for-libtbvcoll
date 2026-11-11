#!/usr/bin/env bash
# 11-12 02:4x: LLAMA_QSA_SHORT=1 은 빨랐으나 출력이 바뀜. =2(인덱서는 그대로 돌리고 마스크만 pool_mask 로) 로 원인 가르기 — 진단(감시기 없음), none 한 회
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; O=$R/fixcost/watchfix-1112
export BENCH_S=900 WATCH=0 CL_qg2="LLAMA_QSA_SHORT=2"
OUTDIR=watchfix-1112 RUNS="none:qg2" bash $R/tools/bench/node-ab.sh
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1t $O/srv-2node-*-bench.txt | head -1)
echo ALLDONE
