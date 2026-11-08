#!/usr/bin/env bash
# 11-08 저녁: MTP 에서 클라이언트 돌기(GGML_RPC_SYNC_SPIN=1) 판정 — 4바퀴 더(속도 회만, 감시기 회는 16:39 에 이미). $1 = 앞 측정 PID.
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll
O=$R/fixcost/boundary-1108
[ -n "$1" ] && while kill -0 $1 2>/dev/null; do sleep 10; done
sleep 20
export CL_sp1="GGML_RPC_SYNC_SPIN=1"
cd $O
WATCH=0 OUTDIR=boundary-1108 RUNS="mtp:sp1 mtp:def mtp:sp1 mtp:def mtp:sp1 mtp:def mtp:sp1 mtp:def" bash $R/tools/bench/node-ab.sh
