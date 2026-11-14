#!/usr/bin/env bash
# 11-14: rxspin tbv(rx_wq_spin_ns) 설치 + A/B. A 의 터미널에서 사용자가 실행 — sudo 비밀번호: A 한 번, B 는 단계마다(3–5번).
#   bash run-rxspin.sh 2>&1 | tee fixcost/rxwq-ab-1114/run-rxspin-$(date +%H%M).log
#   P0=1 bash run-rxspin.sh ...   끝에 rx_wq_poll=0(10-29 방식) 기준 회도 잰다(모듈 다시 올림 2번 더, B 비밀번호 2번 더)
# 왜: 1018 perftest 1케이블 단방향이 9.2 Gb/s(10-29 10.7). 수신 링 인터럽트가 프레임마다 와서(27.1 만/s ≈ 4 KiB 프레임 28.0 만/s)
#   rx_wq_poll=2 의 받기 작업이 프레임마다 인터럽트 가리기·열기(MMIO 읽기+쓰기)와 작업자 깨우기를 되풀이 → tbv_ibdev kworker 합 ≈100%(코어 1개).
#   rxspin = 링이 빈 뒤 rx_wq_spin_ns 동안 더 보고 그사이 오는 프레임은 인터럽트 없이 처리(experiments/lnk-1114-tbv/rxspin.patch).
# 하는 일:
#   0) 확인: 두 노드 1018, 서버 없음, 새 모듈 sha256
#   1) 설치: 두 노드 updates/thunderbolt_ibverbs.ko → 새 모듈(지금 것은 .pre-rxspin.bak 로 복사, 이미 있으면 그대로), depmod, 다시 올림
#      (modprobe.d 그대로 = rx_wq_poll=2, rx_wq_spin_ns 는 모듈 기본 10000). 설정 파일은 건드리지 않는다.
#   2) 1단계(B 는 10000 고정, A 만 바꿈 — sudo 는 A 캐시만): 단방향 B→A × {0, 10000, 3000, 30000, 0}
#   3) 2단계(두 노드 같은 값): {0, 10000} × 단방향+양방향+10 KB 지연(두 케이블)+무결성(10000 때)
#   4) [P0=1] rx_wq_poll=0 기준 1회 후 rx_wq_poll=2 로 되돌림
#   끝 상태 = rx_wq_poll=2, rx_wq_spin_ns=10000 (부팅해도 같음: modprobe.d + 새 모듈 기본값)
# 되돌리기: 두 노드에서 sudo install -m 644 /lib/modules/7.0.0-1018-oem/updates/thunderbolt_ibverbs.ko.pre-rxspin.bak
#           /lib/modules/7.0.0-1018-oem/updates/thunderbolt_ibverbs.ko; sudo depmod -a; 모듈 다시 올림(또는 재부팅).
#   또는 새 모듈 그대로 두고 두 노드에서: echo 0 | sudo tee /sys/module/thunderbolt_ibverbs/parameters/rx_wq_spin_ns (= 11-07 동작)
set -u
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll
S4=/data/parksThink/macos_reversing/codex/zbook-rdma/experiments/step4-tbthroughput
V=$S4/verify
O=$R/fixcost/rxwq-ab-1114; B=parks-zbook@10.99.0.2
K=7.0.0-1018-oem; U=/lib/modules/$K/updates; P=/sys/module/thunderbolt_ibverbs/parameters
NEW_A=/data/parksThink/macos_reversing/codex/zbook-rdma/experiments/lnk-1114-tbv/deploy/thunderbolt_ibverbs.ko
NEW_B=/home/parks-zbook/tbmod-1018/deploy-rxspin/thunderbolt_ibverbs.ko
SHA=d47e33dec9bad63955a0d39d6ffe3cb7d200137f8e83b571550da79bd1f69a7d
SRCV=0BCD6E0C7DE0D7470BAE74F
RUN=$(date +%H%M%S)

st() { printf "A: srcv=%s poll=%s spin=%s ports=%s | B: %s\n" "$(cat /sys/module/thunderbolt_ibverbs/srcversion 2>/dev/null)" \
    "$(cat $P/rx_wq_poll 2>/dev/null)" "$(cat $P/rx_wq_spin_ns 2>/dev/null || echo 없음)" "$(ibv_devinfo 2>/dev/null | grep -c PORT_ACTIVE)" \
    "$(ssh -o BatchMode=yes $B "printf 'srcv=%s poll=%s spin=%s ports=%s' \$(cat /sys/module/thunderbolt_ibverbs/srcversion) \$(cat $P/rx_wq_poll) \$(cat $P/rx_wq_spin_ns 2>/dev/null || echo 없음) \$(ibv_devinfo 2>/dev/null | grep -c PORT_ACTIVE)")"; }
ports_wait() {
    for i in $(seq 40); do
        a=$(ibv_devinfo 2>/dev/null | grep -c PORT_ACTIVE); b=$(ssh -o BatchMode=yes $B "ibv_devinfo 2>/dev/null | grep -c PORT_ACTIVE")
        [ "$a" -ge 2 ] && [ "$b" -ge 2 ] && { sleep 3; return 0; }; sleep 1
    done; echo "포트가 2개씩 안 올라옴"; st; return 1; }
setA() { echo $1 | sudo tee $P/rx_wq_spin_ns > /dev/null && [ "$(cat $P/rx_wq_spin_ns)" = $1 ]; }
setB() { ssh -t $B "sudo -p '[B parks-zbook 비밀번호: spin=$1] ' sh -c 'echo $1 > $P/rx_wq_spin_ns'"; [ "$(ssh -o BatchMode=yes $B cat $P/rx_wq_spin_ns)" = $1 ]; }
bw() {  # bw <tag> <DIRS>
    DEVSETS="usb4_rdma0;usb4_rdma5;usb4_rdma0 usb4_rdma5" QPS=1 SIZES="65536 1048576" DIRS="$2" timeout 600 bash $S4/bw_matrix.sh rxspin-$RUN-$1 5 | sed 's/^/  bw /'
}
irq() { timeout 90 bash $O/irqrate.sh rxspin-$RUN-$1 usb4_rdma0 65536 8 | sed 's/^/  irq /'; }
lat() { for d in usb4_rdma0 usb4_rdma5; do DEV=$d timeout 120 bash $R/fixcost/lnk-1107/lat-spin.sh rxspin-$RUN-$1-$d 20 none 100000 | sed "s/^/  lat $d /"; done; }
verify() {
    mkdir -p $O/verify-$RUN-$1
    for dev in usb4_rdma0 usb4_rdma5; do for q in 1 4; do
        timeout 300 $V/rdma_verify $dev server 18799 200 $q > $O/verify-$RUN-$1/${dev}_q$q.srv 2>&1 & sp=$!; sleep 1
        timeout 300 ssh -o BatchMode=yes $B "~/step4-tbthroughput/verify/rdma_verify $dev client 10.99.0.1 18799 200 $q" > $O/verify-$RUN-$1/${dev}_q$q.cli 2>&1
        wait $sp
        echo "  verify $dev q$q: $(grep -h 'PASS\|FAIL' $O/verify-$RUN-$1/${dev}_q$q.cli | tail -1) | srv: $(grep -h -o 'PASS\|FAIL' $O/verify-$RUN-$1/${dev}_q$q.srv | tail -1)"
    done; done; }
reload() {  # reload <rx_wq_poll 값 또는 빈칸=modprobe.d>
    local a=""; [ -n "$1" ] && a="rx_wq_poll=$1"
    ssh -t $B "sudo -p '[B parks-zbook 비밀번호: 다시 올림 $a] ' sh -c 'rmmod thunderbolt_ibverbs; modprobe thunderbolt_ibverbs $a'" || return 1
    sudo sh -c "rmmod thunderbolt_ibverbs; modprobe thunderbolt_ibverbs $a" || return 1
    ports_wait; }

echo "==== 0) 확인 $(date '+%F %T')"
[ "$(uname -r)" = $K ] && [ "$(ssh -o BatchMode=yes $B uname -r)" = $K ] || { echo "두 노드가 $K 가 아님"; exit 1; }
if pgrep -x llama-server > /dev/null || pgrep -x ggml-rpc-server > /dev/null || pgrep -f 'bench/node-ab.sh' > /dev/null || \
   ssh -o BatchMode=yes $B "pgrep -x ggml-rpc-server || pgrep -x llama-server" > /dev/null; then echo "서버/벤치가 돌고 있음 — 내리고 다시"; exit 1; fi
[ "$(sha256sum $NEW_A | cut -d' ' -f1)" = $SHA ] || { echo "A 새 모듈 sha256 불일치"; exit 1; }
[ "$(ssh -o BatchMode=yes $B sha256sum $NEW_B | cut -d' ' -f1)" = $SHA ] || { echo "B 새 모듈 sha256 불일치"; exit 1; }
st
echo "== A(park2) sudo"; sudo -v || exit 1
( while sleep 50; do sudo -n -v 2>/dev/null || exit; done ) & KA=$!; trap 'kill $KA 2>/dev/null' EXIT

if [ "$(cat /sys/module/thunderbolt_ibverbs/srcversion)" = $SRCV ] && [ "$(ssh -o BatchMode=yes $B cat /sys/module/thunderbolt_ibverbs/srcversion)" = $SRCV ]; then
    echo "==== 1) 이미 새 모듈이 올라와 있음 — 설치 건너뜀"
else
    echo "==== 1) 설치 $(date '+%T')"
    inst="[ -f $U/thunderbolt_ibverbs.ko.pre-rxspin.bak ] || cp -a $U/thunderbolt_ibverbs.ko $U/thunderbolt_ibverbs.ko.pre-rxspin.bak; install -o root -g root -m 644 NEW $U/thunderbolt_ibverbs.ko; depmod -a $K; rmmod thunderbolt_ibverbs; modprobe thunderbolt_ibverbs"
    ssh -t $B "sudo -p '[B parks-zbook 비밀번호: 설치] ' sh -c '${inst/NEW/$NEW_B}'" || { echo "B 설치 실패 — 멈춤"; st; exit 1; }
    sudo sh -c "${inst/NEW/$NEW_A}" || { echo "A 설치 실패 — 멈춤"; st; exit 1; }
    ports_wait || exit 1
fi
st
[ "$(cat /sys/module/thunderbolt_ibverbs/srcversion)" = $SRCV ] && [ "$(cat $P/rx_wq_poll)" = 2 ] || { echo "A 상태가 예상과 다름 — 멈춤"; exit 1; }

echo "==== 2) 1단계: B spin=10000 고정, A 만 바꿈(단방향 B→A) $(date '+%T')"
[ "$(ssh -o BatchMode=yes $B cat $P/rx_wq_spin_ns)" = 10000 ] || setB 10000 || { echo "B 를 10000 으로 못 맞춤"; exit 1; }
for v in 0 10000 3000 30000 0; do
    setA $v || { echo "A spin=$v 실패"; exit 1; }
    echo "== A spin=$v $(date '+%T')"; st
    bw a$v-uni 0; irq a$v
done

echo "==== 3) 2단계: 두 노드 같은 값 $(date '+%T')"
for v in 0 10000; do
    setB $v || { echo "B spin=$v 실패"; exit 1; }
    setA $v || { echo "A spin=$v 실패"; exit 1; }
    echo "== 두 노드 spin=$v $(date '+%T')"; st
    bw ab$v-all "0 1"; lat ab$v; irq ab$v
    [ $v = 10000 ] && verify ab$v
done

if [ "${P0:-0}" = 1 ]; then
    echo "==== 4) rx_wq_poll=0 기준 $(date '+%T')"
    reload 0 || exit 1; st
    bw p0-all "0 1"; lat p0; irq p0
    echo "== rx_wq_poll=2(modprobe.d)로 되돌림"; reload "" || exit 1
fi
st
echo "ALLDONE $(date '+%T')  자료: $S4/raw/rxspin-$RUN-*_bw.sum, $O/irq-rxspin-$RUN-*, $R/fixcost/lnk-1107/out/rxspin-$RUN-*, $O/verify-$RUN-*"
