#!/usr/bin/env bash
# 11-11: 4토큰 묶음 작업 빌드 — 예전 바이너리(11-09 22:42)는 build-rocm3/bin-1109-2242 에 복사해 두고(비교용), build-rocm3 를 이어 빌드
L=/data/parksThink/macos_reversing/codex/zbook-rdma/experiments/engine2n/llama.cpp
set -e
if [ ! -d $L/build-rocm3/bin-1109-2242 ]; then mkdir -p $L/build-rocm3/bin-1109-2242; cp -a $L/build-rocm3/bin/ggml-rpc-server $L/build-rocm3/bin/llama-server $L/build-rocm3/bin/llama-bench $L/build-rocm3/bin-1109-2242/; fi
cd $L && timeout 5400 cmake --build build-rocm3 --target ggml-rpc-server llama-server llama-bench -j 28
ls -la $L/build-rocm3/bin/ggml-rpc-server $L/build-rocm3/bin/llama-server $L/build-rocm3/bin/llama-bench
