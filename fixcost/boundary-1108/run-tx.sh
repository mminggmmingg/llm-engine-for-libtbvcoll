#!/usr/bin/env bash
# 11-08 저녁: 클라이언트 RDMA 보내기 버퍼 수(GGML_RDMA_TX_SLOTS, 스크립트 기본 4) — 단계 시작 명령 18개가 슬롯 4개 완료를 기다리며 하나에 ≈13 µs.
#  def(4) / tx16(클라이언트만 16) / tx8 번갈아 3바퀴 + 감시기 회, 클라이언트 기록 풀기. $1 = 앞 측정 PID.
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll
O=$R/fixcost/boundary-1108
[ -n "$1" ] && while kill -0 $1 2>/dev/null; do sleep 10; done
sleep 20
export CL_tx16="GGML_RDMA_TX_SLOTS=16" CL_tx8="GGML_RDMA_TX_SLOTS=8"
cd $O
WATCH=1 OUTDIR=boundary-1108 RUNS="none:tx16 none:def none:tx8 none:tx16 none:def none:tx8 none:tx16 none:def none:tx8" bash $R/tools/bench/node-ab.sh
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1t $O/srv-2node-none-bs-tx*-bench.txt)
for s in $(ls -1dt $R/runs/watch/2*/ | head -3); do echo "== $s"; python3 -I $O/cchain.py $s; done
