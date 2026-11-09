#!/usr/bin/env bash
# 11-09 저녁 2a 이어서(run-2a1 이 끝난 뒤): 검사 코드(router·top-k weights 비교 빠졌던 것) 고친 빌드 → 검사 회 → 프로파일(2a, 기본) → 단계 도장 → 두 GPU 부하 경쟁
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll
O=$R/fixcost/seg2-1109
L=/data/parksThink/macos_reversing/codex/zbook-rdma/experiments/engine2n/llama.cpp
while pgrep -f "^bash /data.*run-2a1.sh" > /dev/null; do sleep 10; done
echo "== build $(date +%T)"
nice cmake --build $L/build-rocm3 -j 30 --target ggml-rpc-server llama-server llama-bench > $O/build-2a-3.log 2>&1 || { echo "build failed"; exit 1; }
V="GGML_CUDA_SEG_MOE=2 GGML_CUDA_SEG_VERIFY=1"
export SA_tv="$V" SB_tv="$V" SA_t2="GGML_CUDA_SEG_MOE=2" SB_t2="GGML_CUDA_SEG_MOE=2"
export SA_tt="GGML_CUDA_SEG_MOE=2 GGML_CUDA_SEG_TIMES=480" SB_tt="GGML_CUDA_SEG_MOE=2 GGML_CUDA_SEG_TIMES=480"
cd $O
echo "== verify $(date +%T)"
WATCH=0 OUTDIR=seg2-1109 RUNS="none:tv" bash $R/tools/bench/node-ab.sh
d=$(ls -1dt $R/runs/srv-2node-none-bs-tv-* | head -1)
for x in a b; do
  echo "verify $x: $(grep -c 'seg moe tail verify' $d/rpc-$x.log) lines, DIFFER $(grep 'seg moe tail verify' $d/rpc-$x.log | grep -c DIFFER)"
  grep -m1 'seg moe tail verify' $d/rpc-$x.log
done
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1t $O/srv-2node-none-bs-tv-*-bench.txt | head -1)
if [ "$(grep -h 'seg moe tail verify' $d/rpc-a.log $d/rpc-b.log | grep -c DIFFER)" != 0 ]; then echo "verify failed: stop"; exit 1; fi
echo "== profiles $(date +%T)"
SRVX="GGML_CUDA_SEG_MOE=2" bash $R/tools/bench/prof2node.sh t2 64 > $O/prof-t2.log 2>&1
bash $R/tools/bench/prof2node.sh def 64 > $O/prof-def.log 2>&1
for t in t2 def; do
  p=$(ls -1dt $R/runs/prof2node-$t-* | head -1); echo "$t: $p"
  python3 -I $R/fixcost/bigpicture-1108/budget.py $p/a_kernel_trace.csv > $O/budget-$t.md; head -2 $O/budget-$t.md
  python3 -I $O/segtrace.py $p/a_kernel_trace.csv > $O/segtrace-$t.md; head -4 $O/segtrace-$t.md
done
echo "== stage times $(date +%T)"
WATCH=0 OUTDIR=seg2-1109 RUNS="none:tt" bash $R/tools/bench/node-ab.sh
d=$(ls -1dt $R/runs/srv-2node-none-bs-tt-* | head -1)
for x in a b; do echo "$x:"; grep "seg moe times" $d/rpc-$x.log | /usr/bin/tail -n 3; done
echo "== bursts $(date +%T)"
WATCH=0 OUTDIR=seg2-1109 RUNS="none:t2 mtp:t2 none:t2" bash $R/tools/bench/node-ab.sh > $O/burst-t2-runs.log 2>&1 &
NP=$!
bash $O/burst.sh $NP > $O/burst-t2.log 2>&1
wait $NP
grep -v "^   [ab]:" $O/burst-t2-runs.log
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1t $O/srv-2node-*-bs-t2-*-bench.txt | head -3)
echo "== done $(date +%T)"
