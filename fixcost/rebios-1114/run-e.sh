#!/usr/bin/env bash
# 11-14 21:0x: park2(A) BIOS 01.05.07 → 01.06.02(18:45, 다른 세션의 보안 조치) 뒤 엔진 기준 측정 — sudo 없음.
# 모듈은 오전과 같음(thunderbolt 29E32B59, tbv 979EBFFB = rxwq, rx_wq_poll=2) → rxspin(spin 0/10000) 설치 전 "새 BIOS + 지금 모듈" 기준.
# 오전 기준: fixcost/k1018-1114/run-k.sh 의 엔진·해시 부분과 같은 명령(none 46.37 / MTP 62.99, 해시 6/6). 덮개 닫힘 절전 막기: systemd-inhibit(A), B 는 덮개 열림 확인.
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll
B=parks-zbook@10.99.0.2
O=$R/fixcost/rebios-1114
echo "== $(date '+%F %T') A $(uname -r) BIOS $(cat /sys/class/dmi/id/bios_version) | B $(ssh -o BatchMode=yes $B 'uname -r; cat /sys/class/dmi/id/bios_version' | tr '\n' ' ')"
echo "== lid A $(cat /proc/acpi/button/lid/*/state | tr -s ' ') | B $(ssh -o BatchMode=yes $B 'cat /proc/acpi/button/lid/*/state' | tr -s ' ')"
$R/tools/tbv_rxwq.sh status
echo "== engine $(date '+%T')"
export SA_f="" SB_f=""
BENCH_S=600 OUTDIR=rebios-1114 RUNS="none:f none:f none:f mtp:f mtp:f mtp:f" bash $R/tools/bench/node-ab.sh
echo "== hash"
for f in $(ls -1tr $O/srv-2node-*-bs-f-1114-*-bench.txt); do python3 -I $R/fixcost/gluhc-1108/hashchk.py $f; done
echo "== UFW BLOCK on thunderbolt/10.99 since boot: A $(journalctl -k -b --no-pager | grep 'UFW BLOCK' | grep -cE 'IN=thunder|SRC=10\.99') B $(ssh -o BatchMode=yes $B "journalctl -k -b --no-pager | grep 'UFW BLOCK' | grep -cE 'IN=thunder|SRC=10\.99'")"
echo ALLDONE $(date '+%T')
