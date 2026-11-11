#!/usr/bin/env bash
# 11-11 21:1x: sched alloc 안 나누기 — GGML_SCHED_TIME=1(분할·할당·재예약), GGML_META_TIME=1(메타 init_tensor·다시 짓기 블록), KEEP=1, MTP 한 회 + 감시기
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; O=$R/fixcost/rebuild-1111
export BENCH_S=600 WATCH=1 CL_st="GGML_META_CACHE_KEEP=1 GGML_SCHED_TIME=1 GGML_META_TIME=1 LLAMA_GRAPH_TIME=1"
OUTDIR=rebuild-1111 RUNS="mtp:st" bash $R/tools/bench/node-ab.sh
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1t $O/srv-2node-*-bench.txt | head -2)
for d in $(ls -td $R/runs/srv-2node-mtp-bs-st* | head -2); do echo "== $d"; grep -E "sched time|meta init_tensor|meta time" $d/server.log | tail -4 | cut -c1-220; grep "graph time over" $d/server.log | grep -v "ubatch 1)" | tail -1 | cut -c1-220; done
echo ALLDONE
