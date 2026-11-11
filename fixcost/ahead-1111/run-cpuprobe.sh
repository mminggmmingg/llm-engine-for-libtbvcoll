#!/usr/bin/env bash
# 11-11 12:4x: 클라이언트 CPU 탐침(LLAMA_CPU_PROBE=200) — none·MTP 한 회씩, 기록 링 끔
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll
export BENCH_S=600 WATCH=0 CL_cp="LLAMA_CPU_PROBE=200"
OUTDIR=ahead-1111 RUNS="none:cp mtp:cp" bash $R/tools/bench/node-ab.sh
for d in $(ls -td $R/runs/srv-2node-*-bs-cp-* | head -2); do echo "== $d"; grep -c cpu_probe $d/server.log; grep cpu_probe $d/server.log | head -3; grep cpu_probe $d/server.log | sed -n '20,24p;60,64p'; done
