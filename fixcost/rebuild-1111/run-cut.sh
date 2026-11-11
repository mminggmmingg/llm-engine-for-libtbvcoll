#!/usr/bin/env bash
# 11-11 18:3x: 부분그래프 메시지에서 노드 밖 소스를 2단계까지만(GGML_RPC_SER_CUT=2, 클라이언트) — 서버 GC_STATS=2 로 k 별 크기·시간, 해시 확인, 감시기
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; O=$R/fixcost/rebuild-1111
export BENCH_S=600 WATCH=${WATCH:-1} SA_cut="GGML_RPC_GC_STATS=2" SB_cut="GGML_RPC_GC_STATS=2" CL_cut="GGML_RPC_SER_CUT=2" SA_gc2="GGML_RPC_GC_STATS=2" SB_gc2="GGML_RPC_GC_STATS=2"
OUTDIR=rebuild-1111 RUNS="${RUNS:-mtp:cut}" bash $R/tools/bench/node-ab.sh
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1t $O/srv-2node-*-bench.txt | head -4)
for d in $(ls -td $R/runs/srv-2node-mtp-bs-cut* | head -2); do for x in a b; do echo "== $d $x"; grep "graph_compute by k" $d/rpc-$x.log | tail -1 | tr '|' '\n'; done; done
for s in $(ls -td $R/runs/watch/2026111[1-9]-* | head -2); do python3 $R/tools/bench/rebuilds.py $s; done
