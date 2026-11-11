#!/usr/bin/env bash
# 11-11 09:0x: 따라잡기 + 첫 초안 단계 합치기(LLAMA_SPEC_MERGE_CATCHUP=1) vs 기본, 번갈아 3쌍
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; O=$R/fixcost/ahead-1111
export BENCH_S=600 WATCH=0 CL_mc="LLAMA_SPEC_MERGE_CATCHUP=1"
OUTDIR=ahead-1111 RUNS="${RUNS:-mtp:mc mtp:def mtp:mc mtp:def mtp:mc mtp:def}" bash $R/tools/bench/node-ab.sh
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1t $O/srv-2node-*-bench.txt | head -6)
for d in $(ls -td $R/runs/srv-2node-mtp-bs-mc-* | head -3); do grep -h "merge-catchup:\|draft acceptance" $d/server.log | tail -2; done
