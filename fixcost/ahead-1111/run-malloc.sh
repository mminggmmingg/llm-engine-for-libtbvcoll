#!/usr/bin/env bash
# 11-11 13:2x: 다시 짓기 직렬화가 malloc 잠금을 기다리는가 — 클라이언트 할당기 바꿔 직렬화 시간(GGML_RPC_DEDUP_TIME=1) 비교
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll
export BENCH_S=600 WATCH=0
P="GGML_RPC_DEDUP_TIME=1"
export CL_sp="$P"
export CL_spt="$P GLIBC_TUNABLES=glibc.malloc.tcache_max=1048576:glibc.malloc.trim_threshold=268435456:glibc.malloc.top_pad=67108864"
export CL_spj="$P LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libjemalloc.so.2"
OUTDIR=ahead-1111 RUNS="${RUNS:-mtp:spt mtp:spj mtp:sp}" bash $R/tools/bench/node-ab.sh
for c in spt spj sp; do d=$(ls -td $R/runs/srv-2node-mtp-bs-$c-1111-1[3-9]* | head -1); echo "== $c $(grep TOTAL $d/bench.txt)"; grep "graph dedup" $d/server.log | tail -2 | cut -c1-140; done
