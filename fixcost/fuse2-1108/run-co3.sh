#!/usr/bin/env bash
# 11-09 새벽: 4토큰 판 부분합 내보내기 묶음의 MTP 판정 — co / def 번갈아 3바퀴 + 감시기 회(앞 묶음은 한 쌍에서 co −2.8% 였으나 pp4 프로파일은 co 가 빠름)
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll
O=$R/fixcost/fuse2-1108
export SA_co="GGML_CUDA_COMM_OUT_FUSE=1" SB_co="GGML_CUDA_COMM_OUT_FUSE=1"
cd $O
WATCH=1 OUTDIR=fuse2-1108 RUNS="mtp:def mtp:co mtp:def mtp:co mtp:def mtp:co" bash $R/tools/bench/node-ab.sh
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1t $O/srv-2node-mtp-bs-co-1109-0[2-9]*-bench.txt)
