#!/usr/bin/env bash
# speed only (trace rings off, watcher off): base vs pin (engine off TB IRQ CPUs 2,5,6,31) vs devpin (+ AR on usb4_rdma0), 3 rounds, none
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll
P="taskset -c 0,1,3,4,7-30"
export AW_pin="$P" BW_pin="$P" CW_pin="$P"
export SA_devpin="GGML_RPC_COMM_DEV=usb4_rdma0" SB_devpin="GGML_RPC_COMM_DEV=usb4_rdma0" AW_devpin="$P" BW_devpin="$P" CW_devpin="$P"
export TRACE=0 OUTDIR=lnk-1107 RUNS="none:base none:pin none:devpin none:pin none:devpin none:base none:devpin none:base none:pin"
bash $R/tools/bench/node-ab.sh
