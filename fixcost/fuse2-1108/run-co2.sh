#!/usr/bin/env bash
# 11-09 새벽: 부분합 내보내기 묶음을 4토큰(MTP 검증)까지 넓힌 빌드 뒤 — MTP 검증 회, 그다음 def / co / cq(co + Q8_CACHE_PERSIST) MTP 3바퀴·none 2바퀴 + 감시기 회. $1 = 앞 측정 PID.
LL=/data/parksThink/macos_reversing/codex/zbook-rdma/experiments/engine2n/llama.cpp
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll
O=$R/fixcost/fuse2-1108
[ -n "$1" ] && while kill -0 $1 2>/dev/null; do sleep 10; done
echo "== build $(date +%T)"
nice cmake --build $LL/build-rocm3 -j 30 --target ggml-rpc-server llama-server llama-bench > $O/build-co4.log 2>&1 || { echo "build failed"; grep -m5 error $O/build-co4.log; exit 1; }
echo "== built $(date +%T)"
sleep 30
V="GGML_CUDA_COMM_OUT_FUSE=1 GGML_CUDA_COMM_OUT_VERIFY=1 GGML_CUDA_COMM_OUT_STATS=1"
export SA_cv="$V" SB_cv="$V"
export SA_co="GGML_CUDA_COMM_OUT_FUSE=1" SB_co="GGML_CUDA_COMM_OUT_FUSE=1"
export SA_cq="GGML_CUDA_COMM_OUT_FUSE=1 GGML_CUDA_Q8_CACHE_PERSIST=1" SB_cq="GGML_CUDA_COMM_OUT_FUSE=1 GGML_CUDA_Q8_CACHE_PERSIST=1"
cd $O
WATCH=0 OUTDIR=fuse2-1108 RUNS="mtp:cv" bash $R/tools/bench/node-ab.sh
d=$(ls -1dt $R/runs/srv-2node-mtp-bs-cv-* | head -1)
for x in a b; do echo "verify $x: $(grep -c 'comm out verify' $d/rpc-$x.log) lines, DIFFER $(grep 'comm out verify' $d/rpc-$x.log | grep -c DIFFER)"; grep "comm out:" $d/rpc-$x.log | sort | uniq -c | sort -rn | head -3; done
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1t $O/srv-2node-mtp-bs-cv-*-bench.txt | head -1)
if [ "$(grep 'comm out verify' $d/rpc-a.log $d/rpc-b.log | grep -c DIFFER)" != 0 ] || ! grep -q "6/6 same" <(python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1t $O/srv-2node-mtp-bs-cv-*-bench.txt | head -1)); then echo "verify failed: stop"; exit 1; fi
WATCH=1 OUTDIR=fuse2-1108 RUNS="mtp:co mtp:def mtp:cq mtp:co mtp:def mtp:cq mtp:co mtp:def mtp:cq" bash $R/tools/bench/node-ab.sh
WATCH=0 OUTDIR=fuse2-1108 RUNS="none:cq none:co none:def none:cq none:co none:def" bash $R/tools/bench/node-ab.sh
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1t $O/srv-2node-*-bs-c[oq]-1109-0[2-9]*-bench.txt 2>/dev/null)
