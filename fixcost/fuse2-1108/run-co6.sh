#!/usr/bin/env bash
# 11-09 아침 확인: 작은 출력만 붙드는 판에서 MAX_TOKENS=4(m4) 대 기본(def), MTP 2쌍 + 설정마다 감시기 회
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll
O=$R/fixcost/fuse2-1108
export SA_m4="GGML_CUDA_COMM_OUT_MAX_TOKENS=4" SB_m4="GGML_CUDA_COMM_OUT_MAX_TOKENS=4"
cd $O
OUTDIR=fuse2-1108 RUNS="mtp:def mtp:m4 mtp:def mtp:m4" bash $R/tools/bench/node-ab.sh
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1t $O/srv-2node-mtp-bs-*-1109-06*-bench.txt)
