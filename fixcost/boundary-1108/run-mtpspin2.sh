#!/usr/bin/env bash
# 11-08 저녁(B Chrome 닫은 뒤, B 쉼): MTP def / sp1(GGML_RPC_SYNC_SPIN=1) 번갈아 3바퀴 + 감시기 회 — 돌기 기본값 판정
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll
O=$R/fixcost/boundary-1108
export CL_sp1="GGML_RPC_SYNC_SPIN=1"
cd $O
WATCH=1 OUTDIR=boundary-1108 RUNS="mtp:def mtp:sp1 mtp:def mtp:sp1 mtp:def mtp:sp1" bash $R/tools/bench/node-ab.sh
