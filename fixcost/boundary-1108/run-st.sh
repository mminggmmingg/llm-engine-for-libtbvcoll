#!/usr/bin/env bash
# 11-08 낮: 토큰 경계의 입력 복사 시간 재기 — 빌드(GGML_SCHED_TIMES 계측, 기본 꺼짐) 뒤 none 한 회, 클라이언트에 GGML_SCHED_TIMES=25.
# $1 = 앞 측정 PID(끝날 때까지 기다림). 빌드는 측정과 겹치지 않게 여기서만.
LL=/data/parksThink/macos_reversing/codex/zbook-rdma/experiments/engine2n/llama.cpp
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll
O=$R/fixcost/boundary-1108
[ -n "$1" ] && while kill -0 $1 2>/dev/null; do sleep 10; done
echo "== build $(date +%T)"
nice cmake --build $LL/build-rocm3 -j 30 --target ggml-rpc-server llama-server llama-bench > $O/build.log 2>&1 || { echo "build failed"; exit 1; }
echo "== built $(date +%T)"
sleep 30
export CL_st="GGML_SCHED_TIMES=25"
cd $O
WATCH=0 OUTDIR=boundary-1108 RUNS="none:st" bash $R/tools/bench/node-ab.sh
d=$(ls -1dt $R/runs/srv-2node-none-bs-st-* | head -1); echo "run dir $d"
grep sched_times $d/server.log > $O/sched_times.txt; wc -l $O/sched_times.txt
