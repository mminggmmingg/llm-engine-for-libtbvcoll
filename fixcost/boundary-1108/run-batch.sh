#!/usr/bin/env bash
# 11-08 저녁: 클라이언트 명령 묶어 보내기 다시(GGML_RPC_BATCH_MAX, 11-03 에는 −4%) — 단계 시작 SET_TENSOR 18개가 디스패처에서 하나씩 나가 첫 GRAPH_RECOMPUTE 가 ≈160 µs 줄 섬.
#  def(새 기본) / bt(BATCH_MAX=65536) 3바퀴 + 감시기 회, 클라이언트 기록 풀기
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll
O=$R/fixcost/boundary-1108
export CL_bt="GGML_RPC_BATCH_MAX=65536"
cd $O
WATCH=1 OUTDIR=boundary-1108 RUNS="none:bt none:def none:bt none:def none:bt none:def" bash $R/tools/bench/node-ab.sh
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1t $O/srv-2node-none-bs-bt*-bench.txt)
for s in $(ls -1dt $R/runs/watch/2*/ | head -2); do echo "== $s"; python3 -I $O/cring.py $s 0 300 | sed -n '/== before/,$p' | head -12; done
