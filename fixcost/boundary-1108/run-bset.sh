#!/usr/bin/env bash
# 11-08 밤: 입력(SET_TENSOR)끼리만 묶어 보내기(GGML_RPC_BATCH_SET_ONLY=1 + GGML_RPC_BATCH_MAX=65536) 빌드 뒤 def / bs 3바퀴 + 감시기 회. $1 = 앞 측정 PID.
LL=/data/parksThink/macos_reversing/codex/zbook-rdma/experiments/engine2n/llama.cpp
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll
O=$R/fixcost/boundary-1108
[ -n "$1" ] && while kill -0 $1 2>/dev/null; do sleep 10; done
echo "== build $(date +%T)"
nice cmake --build $LL/build-rocm3 -j 30 --target ggml-rpc-server llama-server llama-bench > $O/build8.log 2>&1 || { echo "build failed"; exit 1; }
echo "== built $(date +%T)"
sleep 30
export CL_bs="GGML_RPC_BATCH_MAX=65536 GGML_RPC_BATCH_SET_ONLY=1"
[ -n "$TXBEST" ] && export CL_bs="$CL_bs $TXBEST" CL_def="$TXBEST"
cd $O
WATCH=1 OUTDIR=boundary-1108 RUNS="none:bs none:def none:bs none:def none:bs none:def" bash $R/tools/bench/node-ab.sh
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1t $O/srv-2node-none-bs-bs*-bench.txt)
for s in $(ls -1dt $R/runs/watch/2*/ | head -2); do python3 -I $O/cchain.py $s; grep -E "GPU 쉼: 다음 부분그래프 발행 전 \||GPU 계산 \(" $s/receipt.md | head -2; done
