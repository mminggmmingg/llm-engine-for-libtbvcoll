#!/usr/bin/env bash
# 11-11 14:4x: 워커 직렬화 + 내용 재사용(sd) vs 기본(keep-tail 기본 켬 빌드), 번갈아 3쌍 + 감시기
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; O=$R/fixcost/ahead-1111
export BENCH_S=600 WATCH=1 CL_sd="GGML_RPC_SER_ASYNC=1 GGML_RPC_GRAPH_DEDUP=1"
OUTDIR=ahead-1111 RUNS="${RUNS:-mtp:sd mtp:def mtp:sd mtp:def mtp:sd mtp:def}" bash $R/tools/bench/node-ab.sh
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1t $O/srv-2node-*-bench.txt | head -8)
for s in $(ls -td $R/runs/watch/20261111-1[5]* $R/runs/watch/20261111-14[4-9]* 2>/dev/null | head -2); do python3 $R/tools/bench/rebuilds.py $s; done
