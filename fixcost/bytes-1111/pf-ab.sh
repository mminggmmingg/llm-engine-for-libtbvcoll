#!/usr/bin/env bash
# 11-11: AR 기다림 중 가중치 미리 읽기(GGML_CUDA_COMM_PREFETCH, 기본 16 MB) 끔/켬 — DRAM 바이트/토큰과 tg 속도, 번갈아 3쌍(llama-bench -n 64)
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll
for i in 1 2 3; do
  SRVX="GGML_CUDA_COMM_PREFETCH=0" bash $R/tools/bench/ktdf.sh pf0 64 | tail -1
  bash $R/tools/bench/ktdf.sh pf16 64 | tail -1
done
