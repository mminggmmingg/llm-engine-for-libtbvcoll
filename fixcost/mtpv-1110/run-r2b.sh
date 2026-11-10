#!/usr/bin/env bash
# 11-10: 두 레일 확인 2 — 1토큰 AR(10 KB)까지 나누기(r2a, ZC_MIN 4096) vs 기본(none), r2a vs r2(32 KB 이상만, MTP). 번갈아 2바퀴 + 감시기
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll
O=$R/fixcost/mtpv-1110
X="GGML_RPC_COMM_RAIL2=usb4_rdma5 GGML_RDMA_RX_DEPTH=32"
export SA_r2="$X GGML_RPC_COMM_RAIL2_ZC_MIN=32768" SB_r2="$X GGML_RPC_COMM_RAIL2_ZC_MIN=32768"
export SA_r2a="$X GGML_RPC_COMM_RAIL2_ZC_MIN=4096" SB_r2a="$X GGML_RPC_COMM_RAIL2_ZC_MIN=4096"
cd $O
OUTDIR=mtpv-1110 RUNS="none:r2a none:def none:r2a none:def mtp:r2a mtp:r2 mtp:r2a mtp:r2" bash $R/tools/bench/node-ab.sh
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1t $O/srv-2node-*-bs-*-1110-0[2-9]*-bench.txt | head -12)
