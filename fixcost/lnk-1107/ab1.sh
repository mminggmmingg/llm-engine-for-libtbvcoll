#!/usr/bin/env bash
# link-spike A/B: engine processes free to run anywhere (base) vs kept off the Thunderbolt IRQ CPUs 2,5,6,31 (pin), none, watcher on
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll
P="taskset -c 0,1,3,4,7-30"
export AW_pin="$P" BW_pin="$P" CW_pin="$P"
export OUTDIR=lnk-1107 RUNS="none:base none:pin none:base none:pin"
bash $R/tools/bench/node-ab.sh
