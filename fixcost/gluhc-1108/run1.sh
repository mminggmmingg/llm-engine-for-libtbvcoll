#!/usr/bin/env bash
# 11-08 낮: MoE gate+up(glu_q8, IQ4_XS) warp 당 행 R(GGML_CUDA_GLU_Q8_ROWS=2|4|8)과 hc up 행 4개 한 고리(GGML_CUDA_HC_UP_ILV=1). 값은 그대로여야 함.
# 1단계: none def / g2 / g4 / g8 / ilv 한 바퀴 + 해시 확인. 감시기 회는 2단계(후보만)에서.
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll
for s in A B; do :; done
export SA_g2="GGML_CUDA_GLU_Q8_ROWS=2" SB_g2="GGML_CUDA_GLU_Q8_ROWS=2"
export SA_g4="GGML_CUDA_GLU_Q8_ROWS=4" SB_g4="GGML_CUDA_GLU_Q8_ROWS=4"
export SA_g8="GGML_CUDA_GLU_Q8_ROWS=8" SB_g8="GGML_CUDA_GLU_Q8_ROWS=8"
export SA_ilv="GGML_CUDA_HC_UP_ILV=1" SB_ilv="GGML_CUDA_HC_UP_ILV=1"
cd $R/fixcost/gluhc-1108
WATCH=${WATCH:-0} OUTDIR=gluhc-1108 RUNS="${RUNS:-none:def none:g2 none:g4 none:g8 none:ilv}" bash $R/tools/bench/node-ab.sh
