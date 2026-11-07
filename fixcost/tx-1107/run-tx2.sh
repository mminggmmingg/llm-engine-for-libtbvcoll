#!/usr/bin/env bash
# 11-07 저녁: 송신 쪽 튐 가르기 2 — HIP/HSA 런타임 스레드가 taskset 을 0-31 로 되돌려(ROCr os::CreateThread) TB 받기 CPU 에 앉는지.
# def = 지금 기본, aff = 두 서버와 클라이언트에 HSA_OVERRIDE_CPU_AFFINITY_DEBUG=0(런타임 스레드도 부모 affinity 를 물려받음).
# 속도(기록 끔) def/aff 3쌍 번갈아 + thrdump(1 초마다 스레드별 CPU·누적 시간·허용 CPU), 그다음 감시기 회 def·aff 동안 tbsample.
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll
S=/tmp/claude-1000/-data-parksThink-macos-reversing-claude-code/643ce5c3-138e-406c-bfc6-676a2e96b284/scratchpad/tx
B=parks-zbook@10.99.0.2
O=$R/fixcost/tx-1107
export SA_aff=HSA_OVERRIDE_CPU_AFFINITY_DEBUG=0 SB_aff=HSA_OVERRIDE_CPU_AFFINITY_DEBUG=0 CL_aff=HSA_OVERRIDE_CPU_AFFINITY_DEBUG=0
scp -q $O/thrdump.py $B:/tmp/thrdump.py
taskset -c 20 python3 -I $O/thrdump.py 1300 $S/thr2-A.txt &
ssh -o BatchMode=yes $B "taskset -c 20 python3 -I /tmp/thrdump.py 1300 /tmp/thr2-B.txt" &
OUTDIR=tx-1107 RUNS="none:def none:aff none:def none:aff none:def none:aff" WATCH=0 bash $R/tools/bench/node-ab.sh
taskset -c 20 $S/tbsample 900 500 $S/smp2-A.txt ggml-rpc-server &
ssh -o BatchMode=yes $B "taskset -c 20 /tmp/tbsample 900 500 /tmp/smp2-B.txt ggml-rpc-server" &
sleep 2
OUTDIR=tx-1107 RUNS="none:def none:aff" SPEED=0 WATCH=1 bash $R/tools/bench/node-ab.sh
wait
scp -q $B:/tmp/smp2-B.txt $S/smp2-B.txt; scp -q $B:/tmp/thr2-B.txt $S/thr2-B.txt
ls -la $S/smp2-*.txt $S/thr2-*.txt
