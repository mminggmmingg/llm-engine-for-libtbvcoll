#!/usr/bin/env bash
# 11-08 낮: 경계 입력 복사를 부분그래프마다 재는 계측(GGML_SCHED_TIMES, 고친 판) 빌드 뒤
#  st  = 계측만, sts = 계측 + 클라이언트 기다림 돌기(GGML_RPC_SYNC_SPIN=1: 깨어난 코어가 느린지)
#  그다음 속도 def / spin 3쌍(기록 끔), 감시기 회(def, spin). $1 = 앞 측정 PID.
LL=/data/parksThink/macos_reversing/codex/zbook-rdma/experiments/engine2n/llama.cpp
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll
O=$R/fixcost/boundary-1108
[ -n "$1" ] && while kill -0 $1 2>/dev/null; do sleep 10; done
echo "== build $(date +%T)"
nice cmake --build $LL/build-rocm3 -j 30 --target ggml-rpc-server llama-server llama-bench > $O/build2.log 2>&1 || { echo "build failed"; exit 1; }
echo "== built $(date +%T)"
sleep 30
export CL_st="GGML_SCHED_TIMES=25" CL_sts="GGML_SCHED_TIMES=25 GGML_RPC_SYNC_SPIN=1" CL_spin="GGML_RPC_SYNC_SPIN=1"
cd $O
WATCH=0 OUTDIR=boundary-1108 RUNS="none:st none:sts" bash $R/tools/bench/node-ab.sh
for t in st sts; do d=$(ls -1dt $R/runs/srv-2node-none-bs-$t-* | head -1); grep sched_times $d/server.log > $O/sched_times-$t.txt; echo "$t $(wc -l < $O/sched_times-$t.txt) lines ($d)"; done
WATCH=1 OUTDIR=boundary-1108 RUNS="none:def none:spin none:def none:spin none:def none:spin" bash $R/tools/bench/node-ab.sh
