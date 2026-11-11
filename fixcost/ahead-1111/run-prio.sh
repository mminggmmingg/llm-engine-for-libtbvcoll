#!/usr/bin/env bash
# 11-11 08:1x: 미리 만들기 비용(ah2 −9.4%)이 A GPU 나눠 쓰기 때문인지 — 클라이언트(초안) 스트림을 낮은 우선순위로(GGML_CUDA_STREAM_PRIORITY=low)
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; O=$R/fixcost/ahead-1111
export BENCH_S=600 WATCH=0
export CL_ah2lo="LLAMA_SPEC_AHEAD=2 GGML_CUDA_STREAM_PRIORITY=low LLAMA_SPEC_AHEAD_LOG=$O/log-ah2lo.txt"
export CL_ah1lo="LLAMA_SPEC_AHEAD=1 GGML_CUDA_STREAM_PRIORITY=low LLAMA_SPEC_AHEAD_LOG=$O/log-ah1lo.txt"
export CL_ah1lo9="LLAMA_SPEC_AHEAD=1 LLAMA_SPEC_AHEAD_PMIN=0.9 GGML_CUDA_STREAM_PRIORITY=low LLAMA_SPEC_AHEAD_LOG=$O/log-ah1lo9.txt"
OUTDIR=ahead-1111 RUNS="${RUNS:-mtp:ah2lo mtp:def mtp:ah1lo mtp:ah1lo9}" bash $R/tools/bench/node-ab.sh
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1t $O/srv-2node-*-bench.txt)
for d in $(ls -td $R/runs/srv-2node-mtp-bs-ah*lo* | head -3); do echo "$d: $(grep -h 'STREAM_PRIORITY' $d/server.log | head -1)"; grep -h "draft-ahead" $d/server.log | tail -1; done
