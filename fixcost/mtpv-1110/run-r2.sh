#!/usr/bin/env bash
# 11-10: 4토큰 검증 AR(40 KB)만 두 케이블로 반씩(GGML_RPC_COMM_RAIL2, 32 KB 이상만) — rx_wq_poll=2 뒤 다시. MTP r2/def 번갈아 3바퀴 + 감시기
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll
O=$R/fixcost/mtpv-1110
X="GGML_RPC_COMM_RAIL2=usb4_rdma5 GGML_RPC_COMM_RAIL2_ZC_MIN=32768 GGML_RDMA_RX_DEPTH=32"
export SA_r2="$X" SB_r2="$X"
cd $O
OUTDIR=mtpv-1110 RUNS="mtp:r2 mtp:def mtp:r2 mtp:def mtp:r2 mtp:def" bash $R/tools/bench/node-ab.sh
d=$(ls -1dt $R/runs/srv-2node-mtp-bs-r2-* | head -1)
for x in a b; do echo "$x: $(grep -m1 'second rail' $d/rpc-$x.log) $(grep -m1 'second rail not used' $d/rpc-$x.log)"; done
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1t $O/srv-2node-mtp-bs-*-bench.txt | head -8)
