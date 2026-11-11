#!/usr/bin/env bash
# 11-11 22:3x: 저녁 작업 뒤 기준값(기본: SER_CUT=2, META_CACHE_KEEP=1, unordered_map) — MTP·none 한 회씩 + 감시기, 해시
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; O=$R/fixcost/rebuild-1111
export BENCH_S=600 WATCH=1
OUTDIR=rebuild-1111 RUNS="mtp:fin none:fin mtp:fin none:fin" bash $R/tools/bench/node-ab.sh
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1t $O/srv-2node-*-bench.txt | head -6)
for s in $(grep -o "| 2026111[0-9]-[0-9]* |" $(ls -1t $O/watch-summary-*.md | head -1) | tr -d "| "); do python3 $R/tools/bench/rebuilds.py $R/runs/watch/$s; done
echo ALLDONE
