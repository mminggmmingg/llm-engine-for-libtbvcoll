#!/usr/bin/env bash
# 11-09 새벽: AR 부분합 내보내기를 만드는 커널에 묶기(GGML_CUDA_COMM_OUT_FUSE=1: 부분그래프 마지막 노드 — MoE 가중합·ssm_out·attn_output —
# 를 붙들었다가 다음 호출이 그 결과의 내보내기면 같이 띄움). 1) 빌드 2) 검증 회 3) co / def 3바퀴 + 감시기, MTP 2바퀴 4) 두 GPU 부하 경쟁 시험 5) 프로파일. $1 = 앞 측정 PID.
LL=/data/parksThink/macos_reversing/codex/zbook-rdma/experiments/engine2n/llama.cpp
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll
O=$R/fixcost/fuse2-1108
[ -n "$1" ] && while kill -0 $1 2>/dev/null; do sleep 10; done
echo "== build $(date +%T)"
nice cmake --build $LL/build-rocm3 -j 30 --target ggml-rpc-server llama-server llama-bench > $O/build-co.log 2>&1 || { echo "build failed"; grep -m5 error $O/build-co.log; exit 1; }
echo "== built $(date +%T)"
sleep 30
export SA_cv="GGML_CUDA_COMM_OUT_FUSE=1 GGML_CUDA_COMM_OUT_VERIFY=1" SB_cv="GGML_CUDA_COMM_OUT_FUSE=1 GGML_CUDA_COMM_OUT_VERIFY=1"
export SA_co="GGML_CUDA_COMM_OUT_FUSE=1" SB_co="GGML_CUDA_COMM_OUT_FUSE=1"
cd $O
WATCH=0 OUTDIR=fuse2-1108 RUNS="none:cv" bash $R/tools/bench/node-ab.sh
d=$(ls -1dt $R/runs/srv-2node-none-bs-cv-* | head -1)
echo "verify A: $(grep -c 'comm out verify' $d/rpc-a.log) lines, DIFFER $(grep 'comm out verify' $d/rpc-a.log | grep -c DIFFER)"; grep 'comm out verify' $d/rpc-a.log | head -4
echo "verify B: $(grep -c 'comm out verify' $d/rpc-b.log) lines, DIFFER $(grep 'comm out verify' $d/rpc-b.log | grep -c DIFFER)"
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1t $O/srv-2node-none-bs-cv-*-bench.txt | head -1)
if [ "$(grep 'comm out verify' $d/rpc-a.log $d/rpc-b.log | grep -c DIFFER)" != 0 ] || ! grep -q "6/6 same" <(python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1t $O/srv-2node-none-bs-cv-*-bench.txt | head -1)); then echo "verify failed: stop"; exit 1; fi
WATCH=1 OUTDIR=fuse2-1108 RUNS="none:co none:def none:co none:def none:co none:def" bash $R/tools/bench/node-ab.sh
WATCH=0 OUTDIR=fuse2-1108 RUNS="mtp:co mtp:def mtp:co mtp:def" bash $R/tools/bench/node-ab.sh
echo "== bursts $(date +%T)"
WATCH=0 OUTDIR=fuse2-1108 RUNS="none:co mtp:co none:co" bash $R/tools/bench/node-ab.sh > $O/burst-co-runs.log 2>&1 &
NP=$!
bash $O/burst.sh $NP > $O/burst-co.log 2>&1
wait $NP
grep -v "^   [ab]:" $O/burst-co-runs.log
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1t $O/srv-2node-*-bs-co*-bench.txt)
SRVX="GGML_CUDA_COMM_OUT_FUSE=1" bash $R/tools/bench/prof2node.sh co 64 > $O/prof-co.log 2>&1
d=$(ls -1dt $R/runs/prof2node-co-* | head -1); python3 -I $R/fixcost/bigpicture-1108/budget.py $d/a_kernel_trace.csv > $O/budget-co.md; head -3 $O/budget-co.md
