#!/usr/bin/env bash
# new tbv module (rx_wq_poll=1): RDMA WRITE/READ integrity on both cables, QP 1 and 4, 200 rounds each (server A, client B)
V=/data/parksThink/macos_reversing/codex/zbook-rdma/experiments/step4-tbthroughput/verify
O=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll/fixcost/lnk-1107/rxwq-verify; mkdir -p $O
B=parks-zbook@10.99.0.2
for dev in usb4_rdma0 usb4_rdma5; do
  for q in 1 4; do
    $V/rdma_verify $dev server 18799 200 $q > $O/${dev}_q$q.srv 2>&1 &
    sp=$!
    sleep 1
    ssh -o BatchMode=yes $B "~/step4-tbthroughput/verify/rdma_verify $dev client 10.99.0.1 18799 200 $q" > $O/${dev}_q$q.cli 2>&1
    wait $sp
    echo "$dev q$q: $(grep -h PASS\\\|FAIL $O/${dev}_q$q.cli | tail -1) | srv: $(grep -h -o 'PASS\|FAIL' $O/${dev}_q$q.srv | tail -1)"
  done
done
