#!/usr/bin/env bash
# 11-11 10:3x: 오전 실험의 감시기 회(사용자 규칙 — 실험마다 감시기 결과; 오전 속도 회는 WATCH=0 으로 돌려 빠졌음): 설정마다 기록 켠 회 하나 + DRAM
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; O=$R/fixcost/ahead-1111
export BENCH_S=600 SPEED=0 WATCH=1
export CL_ah2="LLAMA_SPEC_AHEAD=2 LLAMA_SPEC_AHEAD_LOG=$O/log-ah2-w.txt"
export CL_ah1p9="LLAMA_SPEC_AHEAD=1 LLAMA_SPEC_AHEAD_PMIN=0.9 LLAMA_SPEC_AHEAD_LOG=$O/log-ah1p9-w.txt"
export CL_mc="LLAMA_SPEC_MERGE_CATCHUP=1" CL_gk="GGML_CUDA_GRAPH_KEY_SHAPE=1"
export SE_n2="-devd ROCm0 --spec-draft-n-max 2" SE_n4="-devd ROCm0 --spec-draft-n-max 4"
OUTDIR=ahead-1111 RUNS="${RUNS:-mtp:def mtp:ah2 mtp:ah1p9 mtp:mc mtp:gk mtp:n2 mtp:n4}" bash $R/tools/bench/node-ab.sh
