#!/usr/bin/env bash
# 2단계: 커널 시간 확인(A 프로파일러, def / g4 / ilv) 뒤 감시기 회(SPEED=0, 5 설정). $1 = 앞 측정 PID.
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll
O=$R/fixcost/gluhc-1108
[ -n "$1" ] && while kill -0 $1 2>/dev/null; do sleep 10; done
sleep 20
for c in def:"" g4:"GGML_CUDA_GLU_Q8_ROWS=4" ilv:"GGML_CUDA_HC_UP_ILV=1"; do
  t=${c%%:*}; SRVX="${c#*:}" bash $R/tools/bench/prof2node.sh gluhc-$t 48 > $O/prof-$t.log 2>&1
  d=$(ls -1dt $R/runs/prof2node-gluhc-$t-* | head -1); echo "$t $d"; tail -2 $O/prof-$t.log
  sleep 20
done
export SA_g2="GGML_CUDA_GLU_Q8_ROWS=2" SB_g2="GGML_CUDA_GLU_Q8_ROWS=2"
export SA_g4="GGML_CUDA_GLU_Q8_ROWS=4" SB_g4="GGML_CUDA_GLU_Q8_ROWS=4"
export SA_g8="GGML_CUDA_GLU_Q8_ROWS=8" SB_g8="GGML_CUDA_GLU_Q8_ROWS=8"
export SA_ilv="GGML_CUDA_HC_UP_ILV=1" SB_ilv="GGML_CUDA_HC_UP_ILV=1"
cd $O
SPEED=0 WATCH=1 OUTDIR=gluhc-1108 RUNS="none:def none:g2 none:g4 none:g8 none:ilv" bash $R/tools/bench/node-ab.sh
