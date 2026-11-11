#!/usr/bin/env bash
# 11-11 19:4x: SER_CUT 기본 빌드에서 남은 다시 짓기(클라이언트) 나누기 — LLAMA_GRAPH_TIME=1(메모리 적용·reset·build·sched alloc), GGML_META_TIME=1(메타 다시 짓기 블록·부분그래프 발행),
# GGML_META_CACHE_STATS=1(분할 상태 캐시), MTP·none 한 회씩 + 감시기
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; O=$R/fixcost/rebuild-1111
export BENCH_S=600 WATCH=1 CL_gt="LLAMA_GRAPH_TIME=1 GGML_META_TIME=1 GGML_META_CACHE_STATS=1"
OUTDIR=rebuild-1111 RUNS="${RUNS:-mtp:gt none:gt}" bash $R/tools/bench/node-ab.sh
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1t $O/srv-2node-*-bench.txt | head -4)
for d in $(ls -td $R/runs/srv-2node-*-bs-gt-1* | head -2); do echo "== $d"; grep -E "graph time over|meta time|split state cache" $d/server.log | tail -8 | cut -c1-260; done
for s in $(ls -td $R/runs/watch/2026111[1-9]-* | head -2); do python3 $R/tools/bench/rebuilds.py $s; done
echo ALLDONE
