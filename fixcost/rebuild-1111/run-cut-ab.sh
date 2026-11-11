#!/usr/bin/env bash
# 11-11 18:3x: GGML_RPC_SER_CUT=2(클라이언트) 번갈아 — MTP 3쌍 + none 1쌍, 감시기(설정마다), 해시. 그다음 기준 쪽 메시지 크기(서버 GC_STATS=2, KB 칸)
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; O=$R/fixcost/rebuild-1111
export BENCH_S=600 WATCH=1 CL_cut="GGML_RPC_SER_CUT=2" CL_base="GGML_RPC_SER_CUT=0"
OUTDIR=rebuild-1111 RUNS="mtp:base mtp:cut mtp:base mtp:cut mtp:base mtp:cut none:base none:cut" bash $R/tools/bench/node-ab.sh
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1t $O/srv-2node-*-bench.txt | head -12)
for s in $(ls -td $R/runs/watch/2026111[1-9]-* | head -4); do python3 $R/tools/bench/rebuilds.py $s; done
export SA_gc2="GGML_RPC_GC_STATS=2" SB_gc2="GGML_RPC_GC_STATS=2" CL_gc2="GGML_RPC_SER_CUT=0"
OUTDIR=rebuild-1111 RUNS="mtp:gc2" bash $R/tools/bench/node-ab.sh
for d in $(ls -td $R/runs/srv-2node-mtp-bs-gc2-* | head -1); do for x in a b; do echo "== $d $x"; grep "graph_compute by k" $d/rpc-$x.log | tail -1 | tr '|' '\n'; done; done
echo ALLDONE
