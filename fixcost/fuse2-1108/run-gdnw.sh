#!/usr/bin/env bash
# 11-08 밤: GDN 묶은 norm 을 모든 GDN 층에(겹치면 쓰는 블록이 그리드 전체가 끝나기를 기다림) — def(새) / nw(GGML_CUDA_GDN_NORM_NO_WAIT=1, 예전)
#  1) 속도 3바퀴 + 감시기 회, 2) 두 GPU 에 띄엄띄엄 부하를 건 채 none·MTP 해시(경쟁 시험), 3) 프로파일(커널 수)
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll
O=$R/fixcost/fuse2-1108
export SA_nw="GGML_CUDA_GDN_NORM_NO_WAIT=1" SB_nw="GGML_CUDA_GDN_NORM_NO_WAIT=1"
cd $O
WATCH=1 OUTDIR=fuse2-1108 RUNS="none:def none:nw none:def none:nw none:def none:nw" bash $R/tools/bench/node-ab.sh
echo "== bursts $(date +%T)"
WATCH=0 OUTDIR=fuse2-1108 RUNS="none:bu mtp:bu none:bu mtp:bu" bash $R/tools/bench/node-ab.sh > $O/burst-runs.log 2>&1 &
NP=$!
bash $O/burst.sh $NP > $O/burst.log 2>&1
wait $NP
grep -v "^   [ab]:" $O/burst-runs.log
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1t $O/srv-2node-*-bs-def*-bench.txt $O/srv-2node-*-bs-bu-*-bench.txt)
cat $O/burst.log
echo "== profile $(date +%T)"
bash $R/tools/bench/prof2node.sh gdnw 64 > $O/prof.log 2>&1
d=$(ls -1dt $R/runs/prof2node-gdnw-* | head -1); python3 -I $R/fixcost/bigpicture-1108/budget.py $d/a_kernel_trace.csv > $O/budget-gdnw.md; head -3 $O/budget-gdnw.md
