#!/usr/bin/env bash
# 11-11 08:3x: 우선순위가 실제로 걸리는지(stderr 줄) + A rpc-server(검증) high · 클라이언트(초안) low 조합
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; O=$R/fixcost/ahead-1111
export BENCH_S=600 WATCH=0
export CL_ah2lo="LLAMA_SPEC_AHEAD=2 GGML_CUDA_STREAM_PRIORITY=low LLAMA_SPEC_AHEAD_LOG=$O/log-ah2lo.txt"
export CL_ah2pr="LLAMA_SPEC_AHEAD=2 GGML_CUDA_STREAM_PRIORITY=low LLAMA_SPEC_AHEAD_LOG=$O/log-ah2pr.txt" SA_ah2pr="GGML_CUDA_STREAM_PRIORITY=high"
OUTDIR=ahead-1111 RUNS="${RUNS:-mtp:ah2pr mtp:def mtp:ah2lo}" bash $R/tools/bench/node-ab.sh
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1t $O/srv-2node-*-bench.txt | head -3)
for d in $(ls -td $R/runs/srv-2node-mtp-bs-ah2* | head -2); do echo "$d: cli $(grep -h 'STREAM_PRIORITY' $d/server.log | head -1) | A $(grep -h 'STREAM_PRIORITY' $d/rpc-a.log | head -1)"; done
