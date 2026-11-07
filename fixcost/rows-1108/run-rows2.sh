#!/usr/bin/env bash
# 2단계: none def / r4 / r8 2바퀴 + 감시기 회, 그다음 MTP def / r4 2바퀴 + 감시기 회
LL=/data/parksThink/macos_reversing/codex/zbook-rdma/experiments/engine2n/llama.cpp
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll
export BIN_r2=$LL/build-half2/bin BIN_r4=$LL/build-r4/bin BIN_r8=$LL/build-r8/bin
OUTDIR=rows-1108 RUNS="none:def none:r4 none:r8 none:def none:r4 none:r8" bash $R/tools/bench/node-ab.sh
OUTDIR=rows-1108 RUNS="mtp:def mtp:r4 mtp:def mtp:r4" bash $R/tools/bench/node-ab.sh
