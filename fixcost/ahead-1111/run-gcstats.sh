#!/usr/bin/env bash
# 11-11 14:3x: 서버가 새 그래프 하나에 쓰는 시간(GGML_RPC_GC_STATS=1, 두 서버), MTP 한 회
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll
export BENCH_S=600 WATCH=0 SA_gc="GGML_RPC_GC_STATS=1" SB_gc="GGML_RPC_GC_STATS=1"
OUTDIR=ahead-1111 RUNS="mtp:gc" bash $R/tools/bench/node-ab.sh
d=$(ls -td $R/runs/srv-2node-mtp-bs-gc-* | head -1); for x in a b; do echo "== $x"; grep "graph_compute stats" $d/rpc-$x.log | tail -3; done
