#!/usr/bin/env bash
# 11-09 아침: 붙드는 것을 작은 출력(≤64 KB, AR 부분합)으로 한정한 뒤 4토큰 판 다시 — MTP 검사 회, MTP def / m4(MAX_TOKENS=4) 번갈아 3바퀴, none 1쌍
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll
O=$R/fixcost/fuse2-1108
V="GGML_CUDA_COMM_OUT_MAX_TOKENS=4 GGML_CUDA_COMM_OUT_VERIFY=1 GGML_CUDA_COMM_OUT_STATS=1"
export SA_mv="$V" SB_mv="$V" SA_m4="GGML_CUDA_COMM_OUT_MAX_TOKENS=4" SB_m4="GGML_CUDA_COMM_OUT_MAX_TOKENS=4"
cd $O
WATCH=0 OUTDIR=fuse2-1108 RUNS="mtp:mv" bash $R/tools/bench/node-ab.sh
d=$(ls -1dt $R/runs/srv-2node-mtp-bs-mv-* | head -1)
for x in a b; do echo "verify $x: $(grep -c 'comm out verify' $d/rpc-$x.log) lines, DIFFER $(grep 'comm out verify' $d/rpc-$x.log | grep -c DIFFER)"; done
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1t $O/srv-2node-mtp-bs-mv-*-bench.txt | head -1)
if [ "$(grep 'comm out verify' $d/rpc-a.log $d/rpc-b.log | grep -c DIFFER)" != 0 ]; then echo "verify failed: stop"; exit 1; fi
WATCH=0 OUTDIR=fuse2-1108 RUNS="mtp:m4 mtp:def mtp:m4 mtp:def mtp:m4 mtp:def none:def none:m4" bash $R/tools/bench/node-ab.sh
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1t $O/srv-2node-*-bs-m4-*-bench.txt $O/srv-2node-*-bs-def-1109-0[5-9]*-bench.txt)
