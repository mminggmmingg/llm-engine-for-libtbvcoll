#!/usr/bin/env bash
# 3단계: MTP def / r4 3바퀴 더 + 감시기 회 (2단계 MTP 차이가 잡음 안인지 확인)
LL=/data/parksThink/macos_reversing/codex/zbook-rdma/experiments/engine2n/llama.cpp
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll
export BIN_r4=$LL/build-r4/bin
OUTDIR=rows-1108 RUNS="mtp:r4 mtp:def mtp:r4 mtp:def mtp:r4 mtp:def" bash $R/tools/bench/node-ab.sh
