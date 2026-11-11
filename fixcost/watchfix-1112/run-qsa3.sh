#!/usr/bin/env bash
# 11-12 03:1x: LLAMA_QSA_SHORT=2 가 2노드 decode 에서만 출력이 바뀜(1노드·prefill 마스크는 같음) — 오늘 기본값(SER_CUT, META_CACHE_KEEP)을 끈 채로 같은 시험(진단)
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; O=$R/fixcost/watchfix-1112
export BENCH_S=900 WATCH=0 CL_qx="LLAMA_QSA_SHORT=2 GGML_RPC_SER_CUT=0 GGML_META_CACHE_KEEP=0"
OUTDIR=watchfix-1112 RUNS="none:qx" bash $R/tools/bench/node-ab.sh
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1t $O/srv-2node-*-bench.txt | head -1)
echo ALLDONE
