#!/usr/bin/env bash
# 11-10: 4토큰 AR(40 KB)을 케이블 두 개로 나누면 빨라지나 — ib_send_lat 한 방향 지연: 한 레일 10/20/40 KB, 두 레일 동시 20 KB 씩
set -u
B=parks-zbook@10.99.0.2; D=$(dirname "$0")/lat; N=${N:-20000}
one() {  # $1 dev $2 size $3 port $4 tag $5 cpuA $6 cpuB
    ssh -o BatchMode=yes $B "setsid -f taskset -c $6 ib_send_lat -d $1 -x 1 -s $2 -n $N -F -p $3 > /tmp/lat-srv-$4.txt 2>&1 < /dev/null"
    sleep 1.5
    taskset -c $5 ib_send_lat -d $1 -x 1 -s $2 -n $N -F -p $3 10.99.0.2 > $D/$4.txt 2>&1
}
for s in 10240 20480 40960; do one usb4_rdma0 $s 18515 r0-$s 2 2; sleep 1; done
for s in 20480 40960; do one usb4_rdma5 $s 18516 r5-$s 3 3; sleep 1; done
# two rails at once, 20 KB each
one usb4_rdma0 20480 18517 both-r0 2 2 & P1=$!
one usb4_rdma5 20480 18518 both-r5 3 3 & P2=$!
wait $P1 $P2
for f in $D/*.txt; do echo "$(basename $f): $(grep -E '^ *[0-9]+ +[0-9]+' $f | /usr/bin/tail -n 1)"; done
