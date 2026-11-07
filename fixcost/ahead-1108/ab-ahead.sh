#!/usr/bin/env bash
# 11-08 새벽: rx_wq_poll=2 로 링크 튐이 사라진 뒤 ZC=3 앞서기(GGML_RPC_COMM_ZC3_AHEAD, 기본 2) 다시 — def(2) / k1 / k3, none 2바퀴 번갈아 + 감시기 회. 값은 그대로(발행 시점만 다름)
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll
export SA_k1=GGML_RPC_COMM_ZC3_AHEAD=1 SB_k1=GGML_RPC_COMM_ZC3_AHEAD=1 SA_k3=GGML_RPC_COMM_ZC3_AHEAD=3 SB_k3=GGML_RPC_COMM_ZC3_AHEAD=3
OUTDIR=ahead-1108 RUNS="${RUNS:-none:def none:k1 none:k3 none:def none:k1 none:k3}" bash $R/tools/bench/node-ab.sh
