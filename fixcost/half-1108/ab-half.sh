#!/usr/bin/env bash
# 16-bit decode AR 속도: 같은 빌드(build-half2) h0(꺼짐) / bf(GGML_RPC_COMM_HALF=1, bf16) / fp(=2, f16), none 2바퀴 번갈아 + 구성마다 감시기 회
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll
H=/data/parksThink/macos_reversing/codex/zbook-rdma/experiments/engine2n/llama.cpp/build-half2/bin
export BIN_h0=$H BIN_bf=$H BIN_fp=$H
export SA_bf=GGML_RPC_COMM_HALF=1 SB_bf=GGML_RPC_COMM_HALF=1 SA_fp=GGML_RPC_COMM_HALF=2 SB_fp=GGML_RPC_COMM_HALF=2
OUTDIR=half-1108 RUNS="${RUNS:-none:h0 none:bf none:fp none:h0 none:bf none:fp}" bash $R/tools/bench/node-ab.sh
