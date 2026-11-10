#!/usr/bin/env bash
# The RDMA device for the allreduce link on this node, or nothing: tbcommdev.sh
# Prints a device only when tbv finishes received frames in a high-priority work (thunderbolt_ibverbs rx_wq_poll present
# and not 0, tbv branch rx-highpri-poll). Then the AR link does best on the device the client link does not use:
# each subgraph the client sends a burst of commands to B, and on the same device the AR from A waits behind it
# (fixcost/lnk-1107: none +2.0%, MTP +2.1%). On the stock path the second device does not help, so print nothing.
# The client link takes the first device whose GID matches the address (ggml-rpc transport.cpp rdma_probe), and every
# device here carries the same GID, so that is the first in ibv_get_device_list order; print the second.
p=/sys/module/thunderbolt_ibverbs/parameters/rx_wq_poll
[ -r $p ] && [ "$(cat $p)" != 0 ] || exit 0
# tbcommdev.sh rail2: the device for the second AR rail (GGML_RPC_COMM_RAIL2) instead — the first device, the one the client
# link uses; printed only when there is a second device for the AR link itself (2026-11-10: MTP +1.5% with ZC_MIN 32768).
want=2; [ "${1:-}" = rail2 ] && want=1
ibv_devices 2>/dev/null | awk -v w=$want 'NR > 2 && $1 != "" { n++; d[n] = $1 } END { if (n >= 2) print d[w] }'
