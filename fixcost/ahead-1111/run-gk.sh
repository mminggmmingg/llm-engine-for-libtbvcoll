#!/usr/bin/env bash
# 11-11 09:3x: 클라이언트(초안) CUDA 그래프 키를 모양별로(GGML_CUDA_GRAPH_KEY_SHAPE=1) — 기본 / gk / mc+gk / 클라이언트 그래프 끔(ng), 번갈아 2바퀴
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; O=$R/fixcost/ahead-1111
export BENCH_S=600 WATCH=0
export CL_gk="GGML_CUDA_GRAPH_KEY_SHAPE=1" CL_mcgk="LLAMA_SPEC_MERGE_CATCHUP=1 GGML_CUDA_GRAPH_KEY_SHAPE=1" CL_ng="GGML_CUDA_DISABLE_GRAPHS=1"
OUTDIR=ahead-1111 RUNS="${RUNS:-mtp:gk mtp:def mtp:mcgk mtp:ng mtp:gk mtp:def mtp:mcgk mtp:ng}" bash $R/tools/bench/node-ab.sh
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1t $O/srv-2node-*-bench.txt | head -8)
