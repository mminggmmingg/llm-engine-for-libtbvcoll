#!/usr/bin/env bash
# 11-09 밤: MTP 검증(4토큰)에서 토큰들이 전문가를 얼마나 겹쳐 고르나 — GGML_CUDA_MOE_OVERLAP_STATS(디버그, 동기화) MTP 1회
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll
O=$R/fixcost/mtpv-1109
export SA_ov="GGML_CUDA_MOE_OVERLAP_STATS=2000" SB_ov="GGML_CUDA_MOE_OVERLAP_STATS=2000"
cd $O
WATCH=0 OUTDIR=mtpv-1109 RUNS="mtp:ov" bash $R/tools/bench/node-ab.sh
d=$(ls -1dt $R/runs/srv-2node-mtp-bs-ov-* | head -1)
for x in a b; do echo "$x:"; grep "moe overlap" $d/rpc-$x.log | /usr/bin/tail -n 4; done
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1t $O/srv-2node-mtp-bs-ov-*-bench.txt | head -1)
