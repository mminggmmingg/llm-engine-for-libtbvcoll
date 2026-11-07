#!/usr/bin/env bash
# new tbv module + TBPIN: AR device A rdma0 / B rdma0 (rxdev) vs A rdma0 / B rdma5 (rxalt: each node the device its client link does not use), none x3 each; then MTP rxdev/rxalt/rxwq
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll
export SA_rxdev="GGML_RPC_COMM_DEV=usb4_rdma0" SB_rxdev="GGML_RPC_COMM_DEV=usb4_rdma0"
export SA_rxalt="GGML_RPC_COMM_DEV=usb4_rdma0" SB_rxalt="GGML_RPC_COMM_DEV=usb4_rdma5"
export OUTDIR=lnk-1107 TRACE=0
RUNS="none:rxalt none:rxdev none:rxalt none:rxdev none:rxalt none:rxdev mtp:rxalt mtp:rxdev mtp:rxwq mtp:rxalt mtp:rxdev mtp:rxwq" bash $R/tools/bench/node-ab.sh
