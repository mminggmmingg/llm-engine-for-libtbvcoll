#!/usr/bin/env bash
# 11-11 11:4x: 검증 크기가 섞일 때(--spec-draft-p-min) 지금 빌드의 전환 비용 — 메타 다시 짓기 횟수(GGML_META_CACHE_STATS=1) + 속도
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; O=$R/fixcost/ahead-1111
export BENCH_S=900 WATCH=0
export SE_pm5="-devd ROCm0 --spec-draft-p-min 0.5" CL_pm5="GGML_META_CACHE_STATS=1" CL_def="GGML_META_CACHE_STATS=1"
OUTDIR=ahead-1111 RUNS="${RUNS:-mtp:pm5 mtp:def}" bash $R/tools/bench/node-ab.sh
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1t $O/srv-2node-*-bench.txt | head -2)
for d in $(ls -td $R/runs/srv-2node-mtp-bs-pm5-* $R/runs/srv-2node-mtp-bs-def-* | head -2); do echo "== $d"; grep -h "meta_graph_compute" $d/server.log | tail -2; grep -h "draft acceptance" $d/server.log | tail -1; done
