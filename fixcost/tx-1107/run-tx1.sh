#!/usr/bin/env bash
# 11-07 저녁: 송신 쪽 튐 가르기 1 — 지금 기본 설정(새 드라이버 + TBPIN(모든 TB 벡터 CPU 피함) + TBDEV) none 속도 3회(기록 끔), 그다음
# 감시기 회 하나 동안 두 노드에서 tbsample(TB 벡터 인터럽트 + 그 CPU kworker/ksoftirqd + rpc-server 스레드 schedstat, 0.5 ms)
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll
S=/tmp/claude-1000/-data-parksThink-macos-reversing-claude-code/643ce5c3-138e-406c-bfc6-676a2e96b284/scratchpad/tx
B=parks-zbook@10.99.0.2
O=$R/fixcost/tx-1107
OUTDIR=tx-1107 RUNS="none:def none:def none:def" WATCH=0 bash $R/tools/bench/node-ab.sh
taskset -c 20 $S/tbsample 600 500 $S/smp-A.txt ggml-rpc-server &
ssh -o BatchMode=yes $B "taskset -c 20 /tmp/tbsample 600 500 /tmp/smp-B.txt ggml-rpc-server" &
sleep 2
OUTDIR=tx-1107 RUNS="none:def" SPEED=0 WATCH=1 bash $R/tools/bench/node-ab.sh
wait
scp -q $B:/tmp/smp-B.txt $S/smp-B.txt
ls -la $S/smp-A.txt $S/smp-B.txt
