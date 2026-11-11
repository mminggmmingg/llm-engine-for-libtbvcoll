#!/usr/bin/env bash
# 11-11 14:4x: 워커 직렬화 + 내용 같은 그래프는 재사용(GGML_RPC_SER_ASYNC=1 GGML_RPC_GRAPH_DEDUP=1) — 확인 회(통계) 하나
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll
export BENCH_S=600 WATCH=0 CL_sd="GGML_RPC_SER_ASYNC=1 GGML_RPC_GRAPH_DEDUP=1 GGML_RPC_SER_TIME=1"
OUTDIR=ahead-1111 RUNS="${RUNS:-mtp:sd}" bash $R/tools/bench/node-ab.sh
d=$(ls -td $R/runs/srv-2node-mtp-bs-sd-* | head -1); grep "rpc worker" $d/server.log | tail -2; grep -i "not found\|error" $d/server.log $d/rpc-a.log | head -5
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1t $R/fixcost/ahead-1111/srv-2node-mtp-bs-sd-*-bench.txt | head -1)
