#!/usr/bin/env bash
# 11-14: sudo 없이 — ib_write_bw 1회(B→A, 단방향) 동안 두 노드의 NHI 인터럽트 수(/proc/interrupts 차이)와 스레드별 CPU 를 잰다.
# 질문: 데이터 링 인터럽트가 프레임마다 오나(tbv nhi_interrupt_throttle_ns=0 → tb_ring_throttling(ring, 0) = 묶기 끔)?
#   bash irqrate.sh <tag> [dev=usb4_rdma0] [size=65536] [D=5]
set -u
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll
O=$R/fixcost/rxwq-ab-1114/irq-$1-$(date +%H%M%S); mkdir -p $O
DEV=${2:-usb4_rdma0}; S=${3:-65536}; D=${4:-5}; B=parks-zbook@10.99.0.2
snap() { grep thunderbolt /proc/interrupts > $O/$1.A; ssh -o BatchMode=yes $B 'grep thunderbolt /proc/interrupts' > $O/$1.B; }
pkill -x ib_write_bw 2>/dev/null; ssh -o BatchMode=yes $B 'pkill -x ib_write_bw' 2>/dev/null; sleep 0.5
ib_write_bw -d $DEV -x 1 -p 18760 -s $S -q 1 -D $D -F --report_gbits > $O/srv.txt 2>&1 &
sp=$!; sleep 1.5
ssh -o BatchMode=yes $B "ib_write_bw -d $DEV -x 1 -p 18760 -s $S -q 1 -D $D -F --report_gbits 10.99.0.1" > $O/cli.txt 2>&1 &
cp=$!
sleep 2; snap t0; t0=$(date +%s.%N)
top -H -b -n 1 -d 2 -w 200 -o %CPU | head -14 > $O/topA.txt &
ssh -o BatchMode=yes $B 'top -H -b -n 1 -d 2 -w 200 -o %CPU | head -14' > $O/topB.txt &
sleep 2; snap t1; t1=$(date +%s.%N)
wait $cp; wait $sp; wait
python3 -I - "$O" "$t0" "$t1" <<'EOF'
import sys, re
o, t0, t1 = sys.argv[1], float(sys.argv[2]), float(sys.argv[3]); dt = t1 - t0
def rd(p):
    d = {}
    for l in open(p):
        f = l.split(); irq = f[0].rstrip(':')
        cnt = [int(x) for x in f[1:33]]
        name = ' '.join(f[-3:-1])
        d[irq] = (cnt, name)
    return d
for node in 'AB':
    a, b = rd(f'{o}/t0.{node}'), rd(f'{o}/t1.{node}')
    for irq in a:
        c0, name = a[irq]; c1 = b[irq][0]
        dl = [y - x for x, y in zip(c0, c1)]
        tot = sum(dl)
        if tot > 100:
            cpus = ' '.join(f'CPU{i}={v}' for i, v in enumerate(dl) if v)
            print(f'{node} irq {irq:>3} {name:<32} {tot/dt:10.0f}/s  ({cpus})')
bw = [l for l in open(f'{o}/srv.txt') if re.match(r'^\s*\d+\s+\d+', l)]
print('bw:', bw[-1].strip() if bw else 'none', f'(dt={dt:.2f}s)')
if bw:
    g = float(bw[-1].split()[3]); print(f'4 KiB 프레임/s ≈ {g*1e9/8/4096:,.0f}')
EOF
echo "-- topA (수신)"; sed -n '3p;8,14p' $O/topA.txt; echo "-- topB (송신)"; sed -n '3p;8,14p' $O/topB.txt
echo "자료: $O"
