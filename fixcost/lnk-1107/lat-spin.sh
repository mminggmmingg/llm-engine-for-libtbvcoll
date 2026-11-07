#!/usr/bin/env bash
# 10 KB ib_send_lat ping-pong on the AR rail (usb4_rdma0) with busy-loop spinners pinned to chosen CPUs on both nodes.
# usage: lat-spin.sh <tag> <lat cpu, or A:B> <spinner cpus, comma list or none> [iterations]
set -u
TAG=$1; LCPU=$2; SPIN=$3; N=${4:-100000}
LA=${LCPU%%:*}; LB=${LCPU##*:}   # "a:b" pins A and B differently
B=parks-zbook@10.99.0.2
D=$(dirname "$0")/out; mkdir -p $D
OUT=$D/$TAG.txt
SECS=$(( N / 15000 + 20 ))
spin_on() {  # $1 = where (local|B)
    [ "$SPIN" = none ] && return
    for c in ${SPIN//,/ }; do
        if [ "$1" = local ]; then
            timeout $SECS taskset -c $c bash -c 'while :; do :; done' &
        else
            ssh -o BatchMode=yes $B "setsid -f timeout $SECS taskset -c $c bash -c 'while :; do :; done' > /dev/null 2>&1 < /dev/null"
        fi
    done
}
spin_on local; spin_on B
sleep 1
ssh -o BatchMode=yes $B "setsid -f taskset -c $LB ib_send_lat -d usb4_rdma0 -x 1 -s 10240 -n $N -F -H > /tmp/lat-srv-$TAG.txt 2>&1 < /dev/null"
sleep 1.5
taskset -c $LA ib_send_lat -d usb4_rdma0 -x 1 -s 10240 -n $N -F -H 10.99.0.2 > $OUT 2>&1
sleep 1
scp -q $B:/tmp/lat-srv-$TAG.txt $D/$TAG-srv.txt
pkill -P $$ timeout 2>/dev/null
python3 - "$OUT" "$TAG" <<'EOF'
import sys, re
v = []
for l in open(sys.argv[1]):
    m = re.match(r'^\s*(\d+)\s*,\s*([0-9.]+)\s*$', l)
    if m: v.append(float(m.group(2)))
if not v:
    print(sys.argv[2], "no samples"); sys.exit()
v.sort(); n = len(v)
q = lambda p: v[min(n - 1, int(p * n))]
big = [x for x in v if x > 1000]
print("%-14s n %6d med %.1f p99 %.1f p99.9 %.1f max %.0f | >0.2ms %d >1ms %d >2.5ms %d | big: %s" % (
    sys.argv[2], n, q(.5), q(.99), q(.999), v[-1], sum(x > 200 for x in v), len(big), sum(x > 2500 for x in v),
    " ".join("%.0f" % x for x in big[-12:])))
EOF
