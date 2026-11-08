#!/usr/bin/env bash
# 11-08 밤: AR 경계 뒤 shared expert 입력 다시 양자화(토큰당 ≈48) 없애기 — GGML_CUDA_Q8_CACHE_PERSIST=1(부분그래프 넘어 q8_1 캐시, 쓰기 세대 검사)
#  def / qp 3바퀴 + 감시기 회, MTP 2바퀴, 해시, 프로파일(커널 수). $1 = 앞 측정 PID.
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll
O=$R/fixcost/fuse2-1108
[ -n "$1" ] && while kill -0 $1 2>/dev/null; do sleep 10; done
sleep 20
export SA_qp="GGML_CUDA_Q8_CACHE_PERSIST=1" SB_qp="GGML_CUDA_Q8_CACHE_PERSIST=1"
cd $O
WATCH=1 OUTDIR=fuse2-1108 RUNS="none:qp none:def none:qp none:def none:qp none:def" bash $R/tools/bench/node-ab.sh
WATCH=0 OUTDIR=fuse2-1108 RUNS="mtp:qp mtp:def mtp:qp mtp:def" bash $R/tools/bench/node-ab.sh
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1t $O/srv-2node-*-bs-qp*-bench.txt)
SRVX="GGML_CUDA_Q8_CACHE_PERSIST=1" bash $R/tools/bench/prof2node.sh qp 64 > $O/prof-qp.log 2>&1
d=$(ls -1dt $R/runs/prof2node-qp-* | head -1); python3 -I $R/fixcost/bigpicture-1108/budget.py $d/a_kernel_trace.csv > $O/budget-qp.md; head -3 $O/budget-qp.md
