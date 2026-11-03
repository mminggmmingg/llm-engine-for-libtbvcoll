#!/usr/bin/env bash
# 추론 감시 데몬 — A 에서: tools/watch/inferwatch.sh build|start|stop|status|log|snap|report <dir>|tbv-copy|tbv-copy-stop
#   start: 백그라운드로 inferwatch daemon 을 띄운다(B 에는 에이전트를 복사해 ssh 로 띄움). 서버·클라이언트가 기록 링
#          (GGML_RPC_TRACE / GGML_RPC_TRACE_CLIENT, run_tp.sh·srv-probe.sh 가 켬)에 쓰는 동안을 한 세션으로 보고,
#          3 초 쉬면 runs/watch/<시각>/report.html 과 receipt.md 를 만든다. runs/watch/latest 는 마지막 세션.
set -u
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll
W=$R/tools/watch; OUT=$R/runs/watch; BIN=$W/target/release/inferwatch
mkdir -p $OUT
case ${1:-status} in
    build)  (cd $W && cargo build --release 2>&1 | tail -3) ;;
    start)  [ -x $BIN ] || (cd $W && cargo build --release 2>&1 | tail -3)
            if [ -f $OUT/daemon.pid ] && kill -0 $(cat $OUT/daemon.pid) 2>/dev/null; then echo "이미 돌고 있음 (pid $(cat $OUT/daemon.pid))"; exit 0; fi
            setsid -f bash -c "echo \$\$ > $OUT/daemon.pid; exec $BIN daemon --out $OUT >> $OUT/daemon.log 2>&1"
            sleep 1; echo "시작: pid $(cat $OUT/daemon.pid), 기록 $OUT/daemon.log" ;;
    stop)   [ -f $OUT/daemon.pid ] && kill $(cat $OUT/daemon.pid) 2>/dev/null && echo "멈춤"; rm -f $OUT/daemon.pid ;;
    status) if [ -f $OUT/daemon.pid ] && kill -0 $(cat $OUT/daemon.pid) 2>/dev/null; then echo "돌고 있음 (pid $(cat $OUT/daemon.pid))"; else echo "멈춰 있음"; fi
            tail -3 $OUT/daemon.log 2>/dev/null ;;
    log)    tail -n ${2:-30} $OUT/daemon.log ;;
    snap)   $BIN snap --out $OUT ;;
    report) $BIN report "${2:?세션 폴더}" ;;
    tbv-copy)  # tbv 카운터(root 만 읽음)를 1 초마다 /dev/shm/tbv-summary.txt 로 복사하는 고리를 두 노드에 띄움(sudo: A 한 번, B 한 번)
            L='echo $$ > /dev/shm/tbv-copy.pid; while :; do cat /sys/kernel/debug/thunderbolt_ibverbs/summary > /dev/shm/tbv-summary.tmp 2>/dev/null && chmod 644 /dev/shm/tbv-summary.tmp && mv -f /dev/shm/tbv-summary.tmp /dev/shm/tbv-summary.txt; sleep 1; done'
            echo "== A sudo"; sudo setsid -f bash -c "$L"
            echo "== B sudo"; ssh -t parks-zbook@10.99.0.2 "sudo -p '[B parks-zbook 비밀번호] ' setsid -f bash -c '$L'"
            sleep 2; ls -la /dev/shm/tbv-summary.txt; ssh -o BatchMode=yes parks-zbook@10.99.0.2 "ls -la /dev/shm/tbv-summary.txt" ;;
    tbv-copy-stop)
            sudo kill $(cat /dev/shm/tbv-copy.pid) 2>/dev/null && echo "A 멈춤"
            ssh -t parks-zbook@10.99.0.2 "sudo kill \$(cat /dev/shm/tbv-copy.pid) && echo 'B 멈춤'" ;;
    *)      echo "usage: $0 build|start|stop|status|log|snap|report <dir>|tbv-copy|tbv-copy-stop"; exit 2 ;;
esac
