#!/usr/bin/env bash
# 11-14: perftest 대역폭이 10-29 기록보다 6–16% 낮은 원인 가르기 — tbv rx_wq_poll(받기 마무리 위치) 0 / 1 / 2 번갈아.
# 1018 에서 nhi.c(링 코드)는 1015 와 같다. 10-29 이후 바뀐 것: tbv rxwq(11-07) + rx_wq_poll=2(11-08). 지금 수신(A) tbv_ibdev kworker 3–4개 합 ≈100%(= 받기 작업 하나가 코어 1개를 채움), 10-28/29 은 events kworker 하나 26–38%
#   (처음에 "≈60% vs ≈1%" 로 적은 것은 스레드 % 와 전체 평균 sy % 를 섞은 잘못 — 11-14 14:3x 고침).
#   bash run-ab.sh measure <tag>     지금 상태만 잰다(sudo 없음)
#   bash run-ab.sh all               0 → 1 → 2 로 바꾸며 잰다(tools/tbv_rxwq.sh off/on/on2 — 바꿀 때마다 sudo 비밀번호: A 한 번, B 한두 번). 끝 상태 = 2(부팅 설정과 같음)
# 각 회: 대역폭(1케이블 rdma0·rdma5, 2케이블 × 64K·1M × 단방향·양방향, q1, 5 초) + 10 KB 지연(rdma0, 100k) + 1케이블 64K 단방향 중 스레드별 CPU.
set -u
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll
S4=/data/parksThink/macos_reversing/codex/zbook-rdma/experiments/step4-tbthroughput
O=$R/fixcost/rxwq-ab-1114; mkdir -p $O
measure() {
    local tag="$1-$(date +%H%M%S)"
    echo "==== $tag $(date '+%T')"; $R/tools/tbv_rxwq.sh status
    DEVSETS="usb4_rdma0;usb4_rdma5;usb4_rdma0 usb4_rdma5" QPS=1 SIZES="65536 1048576" DIRS="0 1" timeout 400 bash $S4/bw_matrix.sh rxwq-$tag 5 | sed 's/^/  bw /'
    DEV=usb4_rdma0 timeout 120 bash $R/fixcost/lnk-1107/lat-spin.sh rxwq-$tag-rdma0 20 none 100000 | sed 's/^/  lat /'
    OUT_TAG=rxwq-$tag timeout 60 bash $S4/cpu_during.sh 65536 1 usb4_rdma0 8 | sed 's/^/  cpu /'
}
switch() {  # off | on | on2
    echo "==== switch $1 $(date '+%T')"
    $R/tools/tbv_rxwq.sh $1 || { echo "switch $1 실패 — 멈춤"; exit 1; }
    sleep 5
}
case ${1:-} in
    measure) measure ${2:?tag} ;;
    all)
        switch off; measure p0
        switch on;  measure p1
        switch on2; measure p2
        echo ALLDONE ;;
    *) echo "usage: $0 measure <tag> | all"; exit 2 ;;
esac
