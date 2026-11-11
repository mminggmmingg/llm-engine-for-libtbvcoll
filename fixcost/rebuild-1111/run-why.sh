#!/usr/bin/env bash
# 11-11 23:4x: 재사용이 왜 안 되나(GGML_META_REUSE_WHY=60) + 메타 다시 짓기 블록 안 나누기(GGML_META_TIME), MTP 한 회, 진단(감시기 없음)
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; O=$R/fixcost/rebuild-1111
export BENCH_S=600 WATCH=0 CL_why="GGML_META_REUSE=1 GGML_META_REUSE_WHY=60 GGML_META_TIME=1 GGML_META_CACHE_STATS=1"
OUTDIR=rebuild-1111 RUNS="mtp:why" bash $R/tools/bench/node-ab.sh
d=$(ls -td $R/runs/srv-2node-mtp-bs-why-1* | head -1); grep -E "no reuse of" $d/server.log | head -60 | cut -c1-230; grep -E "meta time|simple tensors reused" $d/server.log | tail -3 | cut -c1-260
echo ALLDONE
