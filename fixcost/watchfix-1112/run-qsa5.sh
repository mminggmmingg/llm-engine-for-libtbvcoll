#!/usr/bin/env bash
# 11-12 03:5x: 운영 설정에서만 =2 의 출력이 바뀜 — AR 방식을 OVERLAP=2 로(ZC=3 아님) 두고 기준·=2 비교(진단)
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; O=$R/fixcost/watchfix-1112
export BENCH_S=900 WATCH=0 GGML_RPC_COMM_OVERLAP=2 CL_o0="LLAMA_QSA_SHORT=0" CL_o2="LLAMA_QSA_SHORT=2"
OUTDIR=watchfix-1112 RUNS="none:o0 none:o2" bash $R/tools/bench/node-ab.sh
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1t $O/srv-2node-*-bench.txt | head -2)
echo ALLDONE
