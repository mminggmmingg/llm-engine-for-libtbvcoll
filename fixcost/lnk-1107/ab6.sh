#!/usr/bin/env bash
# new tbv module: AR on its own cable (GGML_RPC_COMM_DEV=usb4_rdma0) + TBPIN default — watcher session, then none x3 alternating with same-cable
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll
export SA_rxdev="GGML_RPC_COMM_DEV=usb4_rdma0" SB_rxdev="GGML_RPC_COMM_DEV=usb4_rdma0" SA_rxdevtr="GGML_RPC_COMM_DEV=usb4_rdma0" SB_rxdevtr="GGML_RPC_COMM_DEV=usb4_rdma0"
export OUTDIR=lnk-1107
$R/tools/watch/inferwatch.sh start
TRACE=1 RUNS="none:rxdevtr" bash $R/tools/bench/node-ab.sh
sleep 15
kill $(cat $R/runs/watch/daemon.pid)
grep "보고서" $R/runs/watch/daemon.log | tail -1
TRACE=0 RUNS="none:rxdev none:rxwq none:rxdev none:rxwq none:rxdev none:rxwq" bash $R/tools/bench/node-ab.sh
