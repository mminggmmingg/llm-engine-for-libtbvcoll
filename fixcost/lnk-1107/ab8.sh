#!/usr/bin/env bash
# new script defaults (TBPIN=1, TBDEV=1) on the new tbv module: none + MTP once each, check the AR device the servers used
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll
export OUTDIR=lnk-1107 TRACE=0 RUNS="none:def2 mtp:def2"
bash $R/tools/bench/node-ab.sh
for d in $(ls -td $R/runs/srv-2node-*def2* | head -2); do echo "$(basename $d): $(cat $d/pin.txt) | A log: $(grep -h 'allreduce link on' $d/rpc-a.log | head -1)"; done
