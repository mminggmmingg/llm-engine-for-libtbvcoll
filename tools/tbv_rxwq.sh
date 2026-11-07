#!/usr/bin/env bash
# tbv 받기 마무리를 높은 우선순위 작업 큐로(rx_wq_poll) — A 에서 실행, 두 노드를 함께: tools/tbv_rxwq.sh install|on|off|restore|status
#   install = 새 모듈(rx_wq_poll 이 있는 판)을 두 노드 /lib/modules/<커널>/updates 에 넣고 rx_wq_poll=1 로 다시 올림.
#             넣기 전에 지금 모듈을 thunderbolt_ibverbs.ko.pre-rxwq.bak 로 복사해 둔다(이미 있으면 그대로). sha256 이 다르면 아무것도 안 함.
#   on/off  = 설치된 새 모듈을 rx_wq_poll=1(CPU 별 system_highpri_wq) / 0(기본 NHI 경로, events kworker)로 다시 올림 — A/B 용
#   restore = .pre-rxwq.bak 을 updates 로 되돌려 놓고 다시 올림(옛 모듈)
# 패치·근거: zbook-thunderbolt-RDMA/tbv 브랜치 rx-highpri-poll, 이 저장소 fixcost/lnk-1107/(RESULTS.md 2026-11-07 08:00 절).
# 모듈은 B 의 ~/kbuild-1015 헤더 + ~/tbmod-1015-upfix/thunderbolt/Module.symvers 로 빌드(같은 환경의 원본 재빌드가 설치본과 기계어 같음).
# 파라미터는 path 가 시작될 때만 읽히므로 모듈을 다시 올린다(링크 재협상 수 초). 설정 파일(/etc/modprobe.d)은 건드리지 않는다.
# sudo 비밀번호를 A 에서 한 번, B 에서(ssh -t) 단계마다 묻는다. rpc-server·llama-server 가 돌고 있으면 아무것도 안 한다.
set -u
B=parks-zbook@10.99.0.2
K=$(uname -r); U=/lib/modules/$K/updates; P=/sys/module/thunderbolt_ibverbs/parameters
NEW_A=/data/parksThink/macos_reversing/codex/zbook-rdma/experiments/lnk-1107-tbv/thunderbolt_ibverbs-rxwq.ko
NEW_B=/home/parks-zbook/tbv-deploy-rxwq-1107/thunderbolt_ibverbs.ko
SHA=f2adab4578b371fb7d108434f4136b7ffabc973abfa8246cb80fd089beb1b1fa
mode=${1:-status}

node_state='printf "srcversion=%s rx_wq_poll=%s " "$(cat /sys/module/thunderbolt_ibverbs/srcversion 2>/dev/null || echo -)" "$(cat /sys/module/thunderbolt_ibverbs/parameters/rx_wq_poll 2>/dev/null || echo 없음)"; ibv_devinfo 2>/dev/null | grep -c PORT_ACTIVE | sed "s/^/ports_active=/"'
show() {
    echo "A: $(bash -c "$node_state")"
    echo "B: $(ssh -o BatchMode=yes $B "$node_state")"
}
case $mode in
    status)  show; exit 0 ;;
    install) v=1 ;;
    on)      v=1 ;;
    off)     v=0 ;;
    restore) v= ;;
    *)       echo "usage: $0 install|on|off|restore|status"; exit 2 ;;
esac

if pgrep -x ggml-rpc-server > /dev/null || pgrep -x llama-server > /dev/null ||
        ssh -o BatchMode=yes $B "pgrep -x ggml-rpc-server" > /dev/null; then
    echo "ggml-rpc-server 또는 llama-server 가 돌고 있음 — 먼저 내리고 다시 실행"; show; exit 1
fi
if [ "$mode" = install ]; then
    [ "$(sha256sum $NEW_A | cut -d' ' -f1)" = $SHA ] || { echo "A 새 모듈 sha256 불일치: $NEW_A"; exit 1; }
    [ "$(ssh -o BatchMode=yes $B "sha256sum $NEW_B" | cut -d' ' -f1)" = $SHA ] || { echo "B 새 모듈 sha256 불일치: $NEW_B"; exit 1; }
fi

# 노드 하나에서 sudo 로 돌릴 명령: 모듈 파일 바꾸기(install/restore) + 내림 [+ 올림]
files_cmd() {  # $1 = 새 모듈 경로
    case $mode in
        install) echo "[ -f $U/thunderbolt_ibverbs.ko.pre-rxwq.bak ] || cp -a $U/thunderbolt_ibverbs.ko $U/thunderbolt_ibverbs.ko.pre-rxwq.bak; install -o root -g root -m 644 $1 $U/thunderbolt_ibverbs.ko; depmod -a $K;" ;;
        restore) echo "[ -f $U/thunderbolt_ibverbs.ko.pre-rxwq.bak ] && install -o root -g root -m 644 $U/thunderbolt_ibverbs.ko.pre-rxwq.bak $U/thunderbolt_ibverbs.ko && depmod -a $K;" ;;
    esac
}
load_args() { [ -n "$v" ] && echo "rx_wq_poll=$v"; }
b_run() {  # $1: 1 이면 다시 올림까지
    local cmd="$(files_cmd $NEW_B) rmmod thunderbolt_ibverbs 2>/dev/null; true"
    [ "$1" = 1 ] && cmd="rmmod thunderbolt_ibverbs 2>/dev/null; modprobe thunderbolt_ibverbs $(load_args)"
    ssh -t $B "sudo -p '[B parks-zbook 비밀번호] ' sh -c '$cmd'"
}
b_value() { ssh -o BatchMode=yes $B "cat $P/rx_wq_poll 2>/dev/null || echo 없음"; }
want() { [ -n "$v" ] && echo $v || echo 없음; }

echo "== A(park2) sudo"
sudo -v || exit 1
echo "== B: 모듈 파일 ($mode) + 내림"
b_run 0 || { echo "B 에서 sudo 실패 — A 는 바꾸지 않음"; show; exit 1; }
echo "== A: 모듈 파일 ($mode) + 다시 올림 $(load_args)"
sudo sh -c "$(files_cmd $NEW_A) rmmod thunderbolt_ibverbs 2>/dev/null; modprobe thunderbolt_ibverbs $(load_args)" || exit 1
sleep 3
if [ "$(b_value)" != "$(want)" ]; then
    echo "== B: 올림 (지금 값 '$(b_value)')"
    b_run 1
fi
for i in $(seq 30); do
    a=$(ibv_devinfo 2>/dev/null | grep -c PORT_ACTIVE)
    b=$(ssh -o BatchMode=yes $B "ibv_devinfo 2>/dev/null | grep -c PORT_ACTIVE")
    [ "$a" -ge 2 ] && [ "$b" -ge 2 ] && break
    sleep 1
done
show
a=$(cat $P/rx_wq_poll 2>/dev/null || echo 없음)
[ "$a" = "$(want)" ] && [ "$(b_value)" = "$(want)" ] && echo "OK: 두 노드 rx_wq_poll=$(want)" || { echo "값이 맞지 않음 — 위 상태 확인"; exit 1; }
