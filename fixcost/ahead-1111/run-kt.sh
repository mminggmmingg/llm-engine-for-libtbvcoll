#!/usr/bin/env bash
# 11-11 12:5x: 생성 한도 직전에도 초안 길이 유지(LLAMA_SPEC_KEEP_TAIL=1) — 검증 크기 3·2·1 로 다시 짓기를 없앰. 번갈아 2쌍 + 감시기
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; O=$R/fixcost/ahead-1111
export BENCH_S=600 WATCH=1 CL_kt="LLAMA_SPEC_KEEP_TAIL=1 GGML_META_CACHE_STATS=1" CL_def="GGML_META_CACHE_STATS=1"
OUTDIR=ahead-1111 RUNS="${RUNS:-mtp:kt mtp:def mtp:kt mtp:def}" bash $R/tools/bench/node-ab.sh
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1t $O/srv-2node-*-bench.txt | head -6)
for d in $(ls -td $R/runs/srv-2node-mtp-bs-kt-* $R/runs/srv-2node-mtp-bs-def-1111-1[23]* | head -6); do echo "$(basename $d): $(grep -h meta_graph_compute $d/server.log | tail -1 | cut -c1-90)"; done
