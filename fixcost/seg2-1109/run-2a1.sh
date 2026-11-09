#!/usr/bin/env bash
# 11-09 저녁: 구간 커널 2a(GGML_CUDA_SEG_MOE=2 — MoE 구간 hc down → 가중합 + 내보내기를 상주 커널 하나로). 검사 회 1, 그다음 none t2/def 번갈아 3바퀴 + 감시기
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll
O=$R/fixcost/seg2-1109
V="GGML_CUDA_SEG_MOE=2 GGML_CUDA_SEG_VERIFY=1"
export SA_tv="$V" SB_tv="$V" SA_t2="GGML_CUDA_SEG_MOE=2" SB_t2="GGML_CUDA_SEG_MOE=2"
cd $O
WATCH=0 OUTDIR=seg2-1109 RUNS="none:tv" bash $R/tools/bench/node-ab.sh
d=$(ls -1dt $R/runs/srv-2node-none-bs-tv-* | head -1)
for x in a b; do
  echo "verify $x: $(grep -c 'seg moe tail verify' $d/rpc-$x.log) lines, DIFFER $(grep 'seg moe tail verify' $d/rpc-$x.log | grep -c DIFFER); $(grep -m1 'ggml_cuda_seg_moe_make' $d/rpc-$x.log)"
  grep -m2 'seg moe tail verify' $d/rpc-$x.log
  grep 'seg moe tail verify' $d/rpc-$x.log | grep -m3 DIFFER
done
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1t $O/srv-2node-none-bs-tv-*-bench.txt | head -1)
if [ "$(grep -h 'seg moe tail verify' $d/rpc-a.log $d/rpc-b.log | grep -c DIFFER)" != 0 ] || [ "$(grep -hc 'seg moe tail verify' $d/rpc-a.log)" = 0 ]; then echo "verify failed or no match: stop"; exit 1; fi
OUTDIR=seg2-1109 RUNS="none:t2 none:def none:t2 none:def none:t2 none:def" bash $R/tools/bench/node-ab.sh
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1t $O/srv-2node-none-bs-t2-*-bench.txt $O/srv-2node-none-bs-def-1109-[12]*-bench.txt | head -12)
