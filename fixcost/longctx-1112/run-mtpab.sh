#!/usr/bin/env bash
# 11-13 01:4x: 확정 빌드의 짧은 문맥 MTP 61.77 t/s 가 11-12 낮 63.6 보다 3% 낮다 — 긴 문맥 커널 세 가지(FA 건너뛰기, 인덱서 직접 읽기, 한 블록 top-k) 탓인지
#   같은 빌드에서 끄기 스위치로 번갈아(on/off ×2, 6 프롬프트, 감시기 회 포함). 짧은 문맥이라 인덱서·top-k 는 대부분 안 돌고(QSA_SHORT) FA 건너뛰기 검사만 남는다.
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; O=$R/fixcost/longctx-1112
F=GGML_CUDA_NO_FA_SKIP=1; G=GGML_CUDA_NO_IDX_GATHER_FUSE=1; T=GGML_CUDA_NO_TOPK_1BLOCK=1
export SA_on="" SB_on="" SA_off="$F $G $T" SB_off="$F $G $T"
BENCH_S=600 WATCH=1 OUTDIR=longctx-1112 RUNS="mtp:on mtp:off mtp:off mtp:on none:on none:off" bash $R/tools/bench/node-ab.sh
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1tr $O/srv-2node-*-o[nf]*-1113-*-bench.txt | tail -6)
echo ALLDONE
