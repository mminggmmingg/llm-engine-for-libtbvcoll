#!/usr/bin/env bash
# new tbv module (rx_wq_poll=1), script defaults (TBPIN=1): none x3 + MTP x2 trace off, then one none session with the watcher
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll
export OUTDIR=lnk-1107 TRACE=0 RUNS="none:rxwq none:rxwq none:rxwq mtp:rxwq mtp:rxwq"
bash $R/tools/bench/node-ab.sh
$R/tools/watch/inferwatch.sh start
export TRACE=1 RUNS="none:rxwqtr"
bash $R/tools/bench/node-ab.sh
sleep 15
kill $(cat $R/runs/watch/daemon.pid)
grep "보고서" $R/runs/watch/daemon.log | tail -1
