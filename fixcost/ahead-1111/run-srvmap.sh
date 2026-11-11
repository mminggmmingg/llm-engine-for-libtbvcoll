#!/usr/bin/env bash
# 11-11 15:2x: 서버 새 그래프 풀기의 unordered_map 두 개를 스레드마다 재사용하는 열린 주소 표로(rpc_id_map) — 새 빌드(nw) vs 14:38 빌드(old),
# MTP 번갈아 3쌍 + none 1쌍 + 감시기(설정마다)
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; O=$R/fixcost/ahead-1111
export BENCH_S=600 WATCH=1 BIN_old=/data/parksThink/macos_reversing/codex/zbook-rdma/experiments/engine2n/llama.cpp/build-rocm3/bin-1111-1438
OUTDIR=ahead-1111 RUNS="${RUNS:-mtp:nw mtp:old mtp:nw mtp:old mtp:nw mtp:old none:nw none:old}" bash $R/tools/bench/node-ab.sh
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1t $O/srv-2node-*-bench.txt | head -12)
for s in $(ls -td $R/runs/watch/20261111-1[5-7]* | head -4); do python3 $R/tools/bench/rebuilds.py $s; done
