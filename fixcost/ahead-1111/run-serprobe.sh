#!/usr/bin/env bash
# 11-11 13:0x: 다시 짓기 때 부분그래프 직렬화 — 한 번 더 연달아 직렬화한 시간과 비교(GGML_RPC_DEDUP_TIME=1, 클라이언트), MTP 한 회
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll
export BENCH_S=600 WATCH=0 CL_sp="GGML_RPC_DEDUP_TIME=1"
OUTDIR=ahead-1111 RUNS="mtp:sp" bash $R/tools/bench/node-ab.sh
d=$(ls -td $R/runs/srv-2node-mtp-bs-sp-* | head -1); grep "graph dedup" $d/server.log | tail -5
