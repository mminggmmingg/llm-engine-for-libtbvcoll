#!/usr/bin/env bash
# 11-12 03:3x: LLAMA_QSA_SHORT=2 가 운영 설정 2노드에서만 출력이 바뀌는 까닭 — 서버 q8_1 활성값 캐시를 끄고(GGML_CUDA_NO_Q8_CACHE=1) 기준·=2 비교(진단)
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; O=$R/fixcost/watchfix-1112
export BENCH_S=900 WATCH=0 SA_n0="GGML_CUDA_NO_Q8_CACHE=1" SB_n0="GGML_CUDA_NO_Q8_CACHE=1" CL_n0="LLAMA_QSA_SHORT=0" SA_n2="GGML_CUDA_NO_Q8_CACHE=1" SB_n2="GGML_CUDA_NO_Q8_CACHE=1" CL_n2="LLAMA_QSA_SHORT=2"
OUTDIR=watchfix-1112 RUNS="none:n0 none:n2" bash $R/tools/bench/node-ab.sh
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1t $O/srv-2node-*-bench.txt | head -2)
echo ALLDONE
