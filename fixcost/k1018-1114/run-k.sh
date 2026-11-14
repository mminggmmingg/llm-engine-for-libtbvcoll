#!/usr/bin/env bash
# 11-14 09:4x: 7.0.0-1018-oem 으로 올린 뒤(사용자가 install-1018.sh·재부팅, thunderbolt 29E32B59 + 0007, tbv 979EBFFB, rx_wq_poll=2 modprobe.d) 확인.
# 기준: 1015 + 같은 tbv + rx_wq_poll=2 의 11-08 00:0x 측정(fixcost/night-1107/run-on2.sh·run-on2.log)과 11-14 07:1x 최종 빌드 해시(final-1114).
# 1) 무결성 rdma_verify 두 케이블 × QP 1·4 × 200회 2) 10 KB ib_send_lat 두 케이블(CPU 20, 회전기 없음) 3) 엔진 none·MTP 3회씩 + 감시기 회 4) 해시.
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll
B=parks-zbook@10.99.0.2
O=$R/fixcost/k1018-1114
V=/data/parksThink/macos_reversing/codex/zbook-rdma/experiments/step4-tbthroughput/verify
echo "== $(date '+%F %T') status (A $(uname -r), B $(ssh -o BatchMode=yes $B uname -r))"; $R/tools/tbv_rxwq.sh status
echo "== integrity"; mkdir -p $O/verify
for dev in usb4_rdma0 usb4_rdma5; do
  for q in 1 4; do
    timeout 300 $V/rdma_verify $dev server 18799 200 $q > $O/verify/${dev}_q$q.srv 2>&1 &
    sp=$!; sleep 1
    timeout 300 ssh -o BatchMode=yes $B "~/step4-tbthroughput/verify/rdma_verify $dev client 10.99.0.1 18799 200 $q" > $O/verify/${dev}_q$q.cli 2>&1
    wait $sp
    echo "$dev q$q: $(grep -h 'PASS\|FAIL' $O/verify/${dev}_q$q.cli | tail -1) | srv: $(grep -h -o 'PASS\|FAIL' $O/verify/${dev}_q$q.srv | tail -1)"
  done
done
echo "== latency 10 KB (no spinners, both nodes on CPU 20)"
for dev in usb4_rdma0 usb4_rdma5; do DEV=$dev timeout 300 bash $R/fixcost/lnk-1107/lat-spin.sh k1018-$dev 20 none 100000; done
echo "== engine $(date '+%T')"
export SA_f="" SB_f=""
BENCH_S=600 OUTDIR=k1018-1114 RUNS="none:f none:f none:f mtp:f mtp:f mtp:f" bash $R/tools/bench/node-ab.sh
echo "== hash"
for f in $(ls -1tr $O/srv-2node-*-bs-f-1114-*-bench.txt); do python3 -I $R/fixcost/gluhc-1108/hashchk.py $f; done
echo ALLDONE
