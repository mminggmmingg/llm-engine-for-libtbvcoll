#!/usr/bin/env bash
# 11-09 새벽 마지막 묶음: 새 기본(GDN 36층 + 부분합 내보내기 묶음 켬)에서 q8 캐시 유지(qp) MTP 3바퀴·none 2바퀴 + 감시기 회(새 기본 none·MTP 포함)
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll
O=$R/fixcost/fuse2-1108
export SA_qp="GGML_CUDA_Q8_CACHE_PERSIST=1" SB_qp="GGML_CUDA_Q8_CACHE_PERSIST=1"
export SA_old="GGML_CUDA_COMM_OUT_FUSE=0 GGML_CUDA_GDN_NORM_NO_WAIT=1" SB_old="GGML_CUDA_COMM_OUT_FUSE=0 GGML_CUDA_GDN_NORM_NO_WAIT=1"
cd $O
WATCH=1 OUTDIR=fuse2-1108 RUNS="mtp:qp mtp:def mtp:qp mtp:def mtp:qp mtp:def" bash $R/tools/bench/node-ab.sh
WATCH=1 OUTDIR=fuse2-1108 RUNS="none:qp none:def none:old none:qp none:def none:old" bash $R/tools/bench/node-ab.sh
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1t $O/srv-2node-*-bs-*-1109-0[4-9]*-bench.txt)
