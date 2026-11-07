#!/usr/bin/env bash
# AR on the client's cable (base) vs its own cable (dev: GGML_RPC_COMM_DEV=usb4_rdma0, NHI IRQs on CPUs 5/6)
# vs own cable + engine kept off the TB IRQ CPUs 2,5,6,31 (devpin); none, watcher on
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll
P="taskset -c 0,1,3,4,7-30"
export SA_dev="GGML_RPC_COMM_DEV=usb4_rdma0" SB_dev="GGML_RPC_COMM_DEV=usb4_rdma0"
export SA_devpin="GGML_RPC_COMM_DEV=usb4_rdma0" SB_devpin="GGML_RPC_COMM_DEV=usb4_rdma0" AW_devpin="$P" BW_devpin="$P" CW_devpin="$P"
export OUTDIR=lnk-1107 RUNS="none:base none:dev none:devpin none:base none:dev none:devpin"
irqs() { awk '/thunderbolt/{s=0; for(i=2;i<=33;i++) s+=$i; printf "%s%s ", $1, s}' /proc/interrupts; }
echo "irq before: $(irqs)"
bash $R/tools/bench/node-ab.sh
echo "irq after: $(irqs)"
