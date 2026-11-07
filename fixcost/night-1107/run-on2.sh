#!/usr/bin/env bash
# 11-08 야간 당직: tbv rx_wq_poll=2(사용자가 00:0x 에 tools/tbv_rxwq.sh on2 로 올림, 받기 작업 = 모듈의 WQ_UNBOUND|WQ_HIGHPRI 큐).
# 1) 무결성(rdma_verify, 두 케이블 × QP 1·4 × 200회) 2) 10 KB ib_send_lat 두 케이블 3) 엔진 none·MTP 3회씩(기록 끔) + 감시기 회(두 노드 tbsample).
# 비교 기준: 같은 부팅 rx_wq_poll=1 의 23:17–23:57 측정(run-night.log, 감시기 20261107-234908). on 으로 되돌리기는 sudo 라 번갈아 재지 않음.
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll
S=/tmp/claude-1000/-data-parksThink-macos-reversing-claude-code/643ce5c3-138e-406c-bfc6-676a2e96b284/scratchpad/tx
B=parks-zbook@10.99.0.2
O=$R/fixcost/night-1107
V=/data/parksThink/macos_reversing/codex/zbook-rdma/experiments/step4-tbthroughput/verify
echo "== $(date '+%F %T') status"; $R/tools/tbv_rxwq.sh status
echo "== integrity"; mkdir -p $O/on2-verify
for dev in usb4_rdma0 usb4_rdma5; do
  for q in 1 4; do
    $V/rdma_verify $dev server 18799 200 $q > $O/on2-verify/${dev}_q$q.srv 2>&1 &
    sp=$!; sleep 1
    ssh -o BatchMode=yes $B "~/step4-tbthroughput/verify/rdma_verify $dev client 10.99.0.1 18799 200 $q" > $O/on2-verify/${dev}_q$q.cli 2>&1
    wait $sp
    echo "$dev q$q: $(grep -h 'PASS\|FAIL' $O/on2-verify/${dev}_q$q.cli | tail -1) | srv: $(grep -h -o 'PASS\|FAIL' $O/on2-verify/${dev}_q$q.srv | tail -1)"
  done
done
echo "== latency 10 KB (no spinners, both nodes on CPU 20)"
for dev in usb4_rdma0 usb4_rdma5; do DEV=$dev bash $R/fixcost/lnk-1107/lat-spin.sh on2-$dev 20 none 100000; done
echo "== engine $(date '+%T')"
scp -q $R/fixcost/tx-1107/tbsample.c $B:/tmp/tbsample.c; ssh -o BatchMode=yes $B "gcc -O2 -o /tmp/tbsample /tmp/tbsample.c"
OUTDIR=night-1107 RUNS="none:def none:def none:def mtp:def mtp:def mtp:def" WATCH=0 bash $R/tools/bench/node-ab.sh
taskset -c 20 $S/tbsample 900 500 $S/smpO-A.txt ggml-rpc-server &
ssh -o BatchMode=yes $B "taskset -c 20 /tmp/tbsample 900 500 /tmp/smpO-B.txt ggml-rpc-server" &
sleep 2
OUTDIR=night-1107 RUNS="none:def mtp:def" SPEED=0 WATCH=1 bash $R/tools/bench/node-ab.sh
wait
scp -q $B:/tmp/smpO-B.txt $S/smpO-B.txt
echo "== done $(date '+%T')"; $R/tools/tbv_rxwq.sh status
