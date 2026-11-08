#!/usr/bin/env bash
# 11-08 낮: 단계 시작의 입력 복사 기다림 없애기(ggml-backend.cpp, 쌓인 일이 없으면 다른 부분그래프 출력 입력도 기다리지 않음) 빌드 뒤
#  st  = 새 기본 + 계측(복사 시간 확인), 그다음 속도 def(새) / old(GGML_SCHED_OTHER_INPUT_SYNC=1, 예전) / dsp(새 + GGML_RPC_SYNC_SPIN=1) 3바퀴 + 감시기 회
LL=/data/parksThink/macos_reversing/codex/zbook-rdma/experiments/engine2n/llama.cpp
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll
O=$R/fixcost/boundary-1108
echo "== build $(date +%T)"
nice cmake --build $LL/build-rocm3 -j 30 --target ggml-rpc-server llama-server llama-bench > $O/build3.log 2>&1 || { echo "build failed"; exit 1; }
echo "== built $(date +%T)"
sleep 30
export CL_st="GGML_SCHED_TIMES=25" CL_old="GGML_SCHED_OTHER_INPUT_SYNC=1" CL_dsp="GGML_RPC_SYNC_SPIN=1"
cd $O
WATCH=0 OUTDIR=boundary-1108 RUNS="none:st" bash $R/tools/bench/node-ab.sh
d=$(ls -1dt $R/runs/srv-2node-none-bs-st-* | head -1); grep sched_times $d/server.log > $O/sched_times-new.txt; python3 -I $O/stsum.py $O/sched_times-new.txt
WATCH=1 OUTDIR=boundary-1108 RUNS="none:def none:old none:dsp none:def none:old none:dsp none:def none:old none:dsp" bash $R/tools/bench/node-ab.sh
python3 -I $R/fixcost/gluhc-1108/hashchk.py $O/srv-2node-none-bs-*-1108-1[3-9]*-bench.txt
