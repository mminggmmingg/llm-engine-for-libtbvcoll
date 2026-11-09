#!/usr/bin/env bash
# 11-09 2단계 준비: 1a 상주 커널(GGML_CUDA_SEG_MOE=1)이 지금 빌드(2138c50)에서도 값 그대로·속도는 어떤지 — 검사 회 1, none s1/def 번갈아 2쌍 + 감시기
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll
O=$R/fixcost/seg2-1109
V="GGML_CUDA_SEG_MOE=1 GGML_CUDA_SEG_VERIFY=1"
export SA_sv="$V" SB_sv="$V" SA_s1="GGML_CUDA_SEG_MOE=1" SB_s1="GGML_CUDA_SEG_MOE=1"
cd $O
WATCH=0 OUTDIR=seg2-1109 RUNS="none:sv" bash $R/tools/bench/node-ab.sh
d=$(ls -1dt $R/runs/srv-2node-none-bs-sv-* | head -1)
for x in a b; do echo "verify $x: $(grep -c 'seg moe verify' $d/rpc-$x.log) lines, DIFFER $(grep 'seg moe verify' $d/rpc-$x.log | grep -c DIFFER)"; done
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1t $O/srv-2node-none-bs-sv-*-bench.txt | head -1)
if [ "$(grep 'seg moe verify' $d/rpc-a.log $d/rpc-b.log | grep -c DIFFER)" != 0 ]; then echo "verify failed: stop"; exit 1; fi
OUTDIR=seg2-1109 RUNS="none:s1 none:def none:s1 none:def" bash $R/tools/bench/node-ab.sh
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1t $O/srv-2node-none-bs-*-bench.txt)
