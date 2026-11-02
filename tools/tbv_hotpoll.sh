#!/usr/bin/env bash
# tbv hot 폴링 켜기/끄기 — A 에서 실행, 두 노드를 함께 바꾼다: tools/tbv_hotpoll.sh on|off|status
#   on  = rx_supp_poll=2 tx_progress_poll=2 (받기·보내기 완료를 커널이 계속 폴링, 노드마다 코어 하나 사용)
#   off = rx_supp_poll=-1 tx_progress_poll=-1 (기본, /etc/modprobe.d 의 설정 파일 값과 같음)
# 파라미터는 path 가 시작될 때만 읽히므로 모듈을 다시 올린다(링크 재협상 수 초). 설정 파일은 건드리지 않는다.
# 순서: B 내림 → A 내리고 새 값으로 올림 → B 확인(A 가 올라올 때 B 가 설정 파일 값으로 저절로 올라오면 B 만 다시).
# sudo 비밀번호를 A 에서 한 번, B 에서(ssh -t) 한두 번 묻는다. rpc-server·llama-server 가 돌고 있으면 아무것도 안 한다.
# 기록: RESULTS.md 2026-11-01 16:47 절.
set -u
B=parks-zbook@10.99.0.2
P=/sys/module/thunderbolt_ibverbs/parameters
mode=${1:-status}
case $mode in
    on)     v=2 ;;
    off)    v=-1 ;;
    status) v= ;;
    *)      echo "usage: $0 on|off|status"; exit 2 ;;
esac

node_state='for f in rx_supp_poll tx_progress_poll; do printf "%s=%s " $f "$(cat /sys/module/thunderbolt_ibverbs/parameters/$f 2>/dev/null || echo -)"; done; ibv_devinfo 2>/dev/null | grep -c PORT_ACTIVE | sed "s/^/ports_active=/"'
show() {
    echo "A: $(bash -c "$node_state")"
    echo "B: $(ssh -o BatchMode=yes $B "$node_state")"
}
b_value() { ssh -o BatchMode=yes $B "cat $P/rx_supp_poll 2>/dev/null"; }

if [ -z "$v" ]; then show; exit 0; fi

if pgrep -x ggml-rpc-server > /dev/null || pgrep -x llama-server > /dev/null ||
        ssh -o BatchMode=yes $B "pgrep -x ggml-rpc-server" > /dev/null; then
    echo "ggml-rpc-server 또는 llama-server 가 돌고 있음 — 먼저 내리고 다시 실행"; show; exit 1
fi

echo "== A(park2) sudo"
sudo -v || exit 1
# B 의 sudo 는 단계마다 한 번만 묻는다(sh -c 로 묶음). sudo 자신의 오류는 숨기지 않는다.
b_reload() {  # $1: 1 이면 다시 올림까지
    local cmd="rmmod thunderbolt_ibverbs 2>/dev/null; true"
    [ "$1" = 1 ] && cmd="rmmod thunderbolt_ibverbs 2>/dev/null; modprobe thunderbolt_ibverbs rx_supp_poll=$v tx_progress_poll=$v"
    ssh -t $B "sudo -p '[B parks-zbook 비밀번호] ' sh -c '$cmd'"
}
echo "== B: 내림"
b_reload 0 || { echo "B 에서 sudo 실패 — 아무것도 바꾸지 않음"; show; exit 1; }
echo "== A: 다시 올림 (rx_supp_poll=$v tx_progress_poll=$v)"
sudo rmmod thunderbolt_ibverbs 2>/dev/null
sudo modprobe thunderbolt_ibverbs rx_supp_poll=$v tx_progress_poll=$v || exit 1
sleep 3
if [ "$(b_value)" != "$v" ]; then
    echo "== B: 올림 (지금 값 '$(b_value)')"
    b_reload 1
fi
for i in $(seq 30); do
    a=$(ibv_devinfo 2>/dev/null | grep -c PORT_ACTIVE)
    b=$(ssh -o BatchMode=yes $B "ibv_devinfo 2>/dev/null | grep -c PORT_ACTIVE")
    [ "$a" -ge 2 ] && [ "$b" -ge 2 ] && break
    sleep 1
done
show
[ "$(cat $P/rx_supp_poll)" = "$v" ] && [ "$(b_value)" = "$v" ] && echo "OK: 두 노드 rx_supp_poll=$v" || { echo "값이 맞지 않음 — 위 상태 확인"; exit 1; }
