#!/usr/bin/env bash
# 11-07 밤(B 미사용): ROCm 런타임 스레드 고정(HSA_OVERRIDE_CPU_AFFINITY_DEBUG=0) 재측정 — fixcost/tx-1107 의 저녁 A/B 는 B 사용 중이었다.
# old = 예전 고정(taskset 만, 런타임 스레드는 0-31 로 되돌아감), def = 지금 기본(env HSA_OVERRIDE_CPU_AFFINITY_DEBUG=0 taskset).
# none 속도(기록 끔) old/def 3쌍 번갈아 + thrdump, 그다음 감시기 회 old·def 동안 두 노드 tbsample.
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll
S=/tmp/claude-1000/-data-parksThink-macos-reversing-claude-code/643ce5c3-138e-406c-bfc6-676a2e96b284/scratchpad/tx
B=parks-zbook@10.99.0.2
LA=$(bash $R/tools/bench/tbcpus.sh); LB=$(ssh -o BatchMode=yes $B "bash -s" < $R/tools/bench/tbcpus.sh)
export AW_old="taskset -c $LA" CW_old="taskset -c $LA" BW_old="taskset -c $LB"
echo "old: A/client taskset -c $LA, B taskset -c $LB"
scp -q $R/fixcost/tx-1107/thrdump.py $B:/tmp/thrdump.py; scp -q $R/fixcost/tx-1107/tbsample.c $B:/tmp/tbsample.c
ssh -o BatchMode=yes $B "gcc -O2 -o /tmp/tbsample /tmp/tbsample.c"
taskset -c 20 python3 -I $R/fixcost/tx-1107/thrdump.py 1700 $S/thrN-A.txt &
ssh -o BatchMode=yes $B "taskset -c 20 python3 -I /tmp/thrdump.py 1700 /tmp/thrN-B.txt" &
OUTDIR=night-1107 RUNS="none:old none:def none:old none:def none:old none:def" WATCH=0 bash $R/tools/bench/node-ab.sh
taskset -c 20 $S/tbsample 900 500 $S/smpN-A.txt ggml-rpc-server &
ssh -o BatchMode=yes $B "taskset -c 20 /tmp/tbsample 900 500 /tmp/smpN-B.txt ggml-rpc-server" &
sleep 2
OUTDIR=night-1107 RUNS="none:old none:def" SPEED=0 WATCH=1 bash $R/tools/bench/node-ab.sh
wait
scp -q $B:/tmp/smpN-B.txt $S/smpN-B.txt; scp -q $B:/tmp/thrN-B.txt $S/thrN-B.txt
ls -la $S/smpN-*.txt $S/thrN-*.txt
