#!/usr/bin/env bash
# 11-14 21:3x: 재부팅 직후(rxspin 모듈 0BCD6E0C 가 부팅 때 올라온 상태) spin 10000 ↔ 0 비교. A 터미널에서 사용자가 실행 — sudo: A 한 번, B 2번.
#   bash fixcost/rxwq-ab-1114/run-postboot.sh 2>&1 | tee fixcost/rxwq-ab-1114/run-postboot-$(date +%H%M).log
# 왜: run-rxspin(21:05–21:17)은 설치 때 모듈을 다시 올린 상태에서 쟀는데, 그때는 spin 0(= 이전과 같은 코드)도 1케이블 11.2 Gb/s 였다.
#   부팅 때 올라온 모듈(오전 10:46, 20:58)은 같은 코드로 9.2 였다. 부팅 상태에서 spin 10000 이 9.2 → 11.2 로 되돌리는지, spin 0 은 다시 9.2 인지 본다.
# 하는 일: 0) 확인(1018, 두 노드 0BCD6E0C 가 부팅 때 올라옴, 덮개·apt·서버) 1) spin 10000(기본, 부팅 그대로) 단방향+인터럽트
#          2) 두 노드 spin 0: 단방향+인터럽트+지연 3) 두 노드 spin 10000: 단·양방향+지연+인터럽트. 끝 상태 = spin 10000(기본).
if [ -z "${RXSPIN_INHIBITED:-}" ] && command -v systemd-inhibit > /dev/null; then
    if systemd-inhibit --what=sleep:idle:handle-lid-switch --who=run-postboot --why=probe true 2> /dev/null; then
        export RXSPIN_INHIBITED=1
        exec systemd-inhibit --what=sleep:idle:handle-lid-switch --who=run-postboot --why="tbv rxspin post-boot A/B" bash "$0" "$@"
    fi
    echo "주의: A 에서 절전 막기(systemd-inhibit) 권한이 없음 — A 덮개를 열어 두세요"
fi
set -u
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll
S4=/data/parksThink/macos_reversing/codex/zbook-rdma/experiments/step4-tbthroughput
O=$R/fixcost/rxwq-ab-1114; B=parks-zbook@10.99.0.2
K=7.0.0-1018-oem; P=/sys/module/thunderbolt_ibverbs/parameters
SRCV=0BCD6E0C7DE0D7470BAE74F
RUN=pb$(date +%H%M%S)

st() { printf "A: srcv=%s poll=%s spin=%s ports=%s | B: %s\n" "$(cat /sys/module/thunderbolt_ibverbs/srcversion 2>/dev/null)" \
    "$(cat $P/rx_wq_poll 2>/dev/null)" "$(cat $P/rx_wq_spin_ns 2>/dev/null || echo 없음)" "$(ibv_devinfo 2>/dev/null | grep -c PORT_ACTIVE)" \
    "$(ssh -o BatchMode=yes $B "printf 'srcv=%s poll=%s spin=%s ports=%s' \$(cat /sys/module/thunderbolt_ibverbs/srcversion) \$(cat $P/rx_wq_poll) \$(cat $P/rx_wq_spin_ns 2>/dev/null || echo 없음) \$(ibv_devinfo 2>/dev/null | grep -c PORT_ACTIVE)")"; }
lid_ok() {
    local a b; a=$(cat /proc/acpi/button/lid/*/state 2>/dev/null | awk '{print $2}'); b=$(ssh -o BatchMode=yes $B "cat /proc/acpi/button/lid/*/state" 2>/dev/null | awk '{print $2}')
    [ "$a" = open ] && [ "$b" = open ] || { echo "덮개 상태 A=$a B=$b — 둘 다 열어 두세요(닫으면 AC 에서도 절전)"; return 1; }; }
apt_ok() {
    local q="pgrep -f '^/usr/bin/python3 /usr/bin/unattended-upgrade( |\$)|^/usr/bin/dpkg |^/usr/bin/apt(-get)? ' > /dev/null && echo busy; t=\$(systemctl show -P NextElapseUSecRealtime --timestamp=unix apt-daily-upgrade.timer 2>/dev/null | tr -d @); [ -n \"\$t\" ] && [ \$((t - \$(date +%s))) -lt 1200 ] && echo soon; true"
    local a b; a=$(bash -c "$q"); b=$(ssh -o BatchMode=yes $B "$q")
    [ -z "$a$b" ] || { echo "apt: A=[$a] B=[$b] — unattended-upgrades 가 돌거나 20분 안에 돎. 끝난 뒤 다시"; return 1; }; }
loadinfo() {  # 모듈이 올라온 시각(커널 기록)과 부팅 시각
    local q="echo \"boot=\$(uptime -s) tbv_loaded=\$(journalctl -k -b --no-pager -o short-iso 2>/dev/null | grep 'thunderbolt_ibverbs: loaded' | tail -1 | cut -c1-19) n_loads=\$(journalctl -k -b --no-pager 2>/dev/null | grep -c 'thunderbolt_ibverbs: loaded')\""
    echo "A: $(bash -c "$q") | B: $(ssh -o BatchMode=yes $B "$q")"; }
setA() { echo $1 | sudo tee $P/rx_wq_spin_ns > /dev/null && [ "$(cat $P/rx_wq_spin_ns)" = $1 ]; }
setB() { ssh -t $B "sudo -p '[B parks-zbook 비밀번호: spin=$1] ' sh -c 'echo $1 > $P/rx_wq_spin_ns'"; [ "$(ssh -o BatchMode=yes $B cat $P/rx_wq_spin_ns)" = $1 ]; }
bw() { DEVSETS="usb4_rdma0;usb4_rdma5;usb4_rdma0 usb4_rdma5" QPS=1 SIZES="65536 1048576" DIRS="$2" timeout 600 bash $S4/bw_matrix.sh rxspin-$RUN-$1 5 | sed 's/^/  bw /'; }
irq() { timeout 90 bash $O/irqrate.sh rxspin-$RUN-$1 usb4_rdma0 65536 8 | sed 's/^/  irq /'; }
lat() { for d in usb4_rdma0 usb4_rdma5; do DEV=$d timeout 120 bash $R/fixcost/lnk-1107/lat-spin.sh rxspin-$RUN-$1-$d 20 none 100000 | sed "s/^/  lat $d /"; done; }

echo "==== 0) 확인 $(date '+%F %T')"
[ "$(uname -r)" = $K ] && [ "$(ssh -o BatchMode=yes $B uname -r)" = $K ] || { echo "두 노드가 $K 가 아님"; exit 1; }
if pgrep -x llama-server > /dev/null || pgrep -x ggml-rpc-server > /dev/null || pgrep -f 'bench/node-ab.sh' > /dev/null || \
   pgrep -x ib_write_bw > /dev/null || pgrep -x ib_send_lat > /dev/null || \
   ssh -o BatchMode=yes $B "pgrep -x ggml-rpc-server || pgrep -x rpc-server || pgrep -x llama-server || pgrep -x ib_write_bw" > /dev/null; then echo "서버/벤치가 돌고 있음 — 끝난 뒤 다시"; exit 1; fi
lid_ok || exit 1
apt_ok || exit 1
for i in $(seq 60); do
    a=$(ibv_devinfo 2>/dev/null | grep -c PORT_ACTIVE); b=$(ssh -o BatchMode=yes $B "ibv_devinfo 2>/dev/null | grep -c PORT_ACTIVE")
    [ "$a" -ge 2 ] && [ "$b" -ge 2 ] && break; sleep 2
done
st; loadinfo
[ "$(cat /sys/module/thunderbolt_ibverbs/srcversion)" = $SRCV ] && [ "$(ssh -o BatchMode=yes $B cat /sys/module/thunderbolt_ibverbs/srcversion)" = $SRCV ] || { echo "새 모듈(0BCD6E0C)이 아님 — 멈춤"; exit 1; }
[ "$(cat $P/rx_wq_poll)" = 2 ] && [ "$(cat $P/rx_wq_spin_ns)" = 10000 ] || { echo "A 가 rx_wq_poll=2 / spin 10000 이 아님 — 멈춤"; exit 1; }
echo "== A(park2) sudo"; sudo -v || exit 1
( while sleep 50; do sudo -n -v 2>/dev/null || exit; done ) & KA=$!; trap 'kill $KA 2>/dev/null' EXIT

echo "==== 1) 부팅 그대로 spin 10000 $(date '+%T')"
bw b10000-uni 0; irq b10000

echo "==== 2) 두 노드 spin 0 $(date '+%T')"
setB 0 || { echo "B spin=0 실패"; exit 1; }; setA 0 || { echo "A spin=0 실패"; exit 1; }; st
bw b0-all "0 1"; irq b0; lat b0

echo "==== 3) 두 노드 spin 10000 $(date '+%T')"
setB 10000 || { echo "B spin=10000 실패"; exit 1; }; setA 10000 || { echo "A spin=10000 실패"; exit 1; }; st
bw b10000-all "0 1"; irq b10000b; lat b10000
st
ufw_q="journalctl -k -b --no-pager 2>/dev/null | grep 'UFW BLOCK' | grep -cE 'IN=thunder|SRC=10\.99'"
echo "UFW BLOCK(thunderbolt·10.99, 부팅 뒤): A $(bash -c "$ufw_q") B $(ssh -o BatchMode=yes $B "$ufw_q")"
echo "ALLDONE $(date '+%T')  자료: $S4/raw/rxspin-$RUN-*_bw.sum, $O/irq-rxspin-$RUN-*, $R/fixcost/lnk-1107/out/rxspin-$RUN-*"
