#!/usr/bin/env bash
# 11-11 14:2x: 워커가 직렬화하는 시간과 보내는 시간(GGML_RPC_SER_ASYNC=1 GGML_RPC_SER_TIME=1), MTP 한 회
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll
export BENCH_S=600 WATCH=0 CL_st="GGML_RPC_SER_ASYNC=1 GGML_RPC_SER_TIME=1"
OUTDIR=ahead-1111 RUNS="mtp:st" bash $R/tools/bench/node-ab.sh
d=$(ls -td $R/runs/srv-2node-mtp-bs-st-* | head -1); grep "rpc worker" $d/server.log | tail -6
