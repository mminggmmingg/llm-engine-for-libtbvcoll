#!/usr/bin/env bash
# 11-11 21:3x: GGML_META_CACHE_KEEP 번갈아(같은 빌드: SER_CUT 기본 + unordered_map) — MTP 3쌍 + none 1쌍, 감시기(설정마다), 해시;
# 그다음 진단 한 회(KEEP + STATS: 분할 상태가 바뀐 텐서 이름, 감시기 없음)
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; O=$R/fixcost/rebuild-1111
export BENCH_S=600 WATCH=1 CL_k0="GGML_META_CACHE_KEEP=0" CL_k1="GGML_META_CACHE_KEEP=1"
OUTDIR=rebuild-1111 RUNS="mtp:k0 mtp:k1 mtp:k0 mtp:k1 mtp:k0 mtp:k1 none:k0 none:k1" bash $R/tools/bench/node-ab.sh
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1t $O/srv-2node-*-bench.txt | head -12)
for s in $(grep -o "| 2026111[0-9]-[0-9]* |" $(ls -1t $O/watch-summary-*.md | head -1) | tr -d "| "); do python3 $R/tools/bench/rebuilds.py $R/runs/watch/$s; done
export WATCH=0 CL_kd="GGML_META_CACHE_KEEP=1 GGML_META_CACHE_STATS=1"
OUTDIR=rebuild-1111 RUNS="mtp:kd" bash $R/tools/bench/node-ab.sh
d=$(ls -td $R/runs/srv-2node-mtp-bs-kd-1* | head -1); grep -E "changed its split state|keep\):" $d/server.log | tail -45 | cut -c1-220
echo ALLDONE
