#!/usr/bin/env bash
# 11-11 18:2x: 다시 짓는 단계에서 서버의 새 그래프 처리 시간이 부분그래프 순번 k 에 따라 늘어나는 까닭 — GGML_RPC_GC_STATS=2(받기·준비·풀기·발행·스레드 CPU·CPU 탐침, k 별), MTP 한 회 + 감시기
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll
export BENCH_S=600 WATCH=1 SA_gc2="GGML_RPC_GC_STATS=2" SB_gc2="GGML_RPC_GC_STATS=2"
OUTDIR=rebuild-1111 RUNS="${RUNS:-mtp:gc2}" bash $R/tools/bench/node-ab.sh
for d in $(ls -td $R/runs/srv-2node-mtp-bs-gc2-* | head -2); do for x in a b; do echo "== $d $x"; grep "graph_compute by k" $d/rpc-$x.log | tail -2; done; done
