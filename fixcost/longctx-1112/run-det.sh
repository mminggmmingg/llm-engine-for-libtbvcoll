#!/usr/bin/env bash
# 11-12 20:0x: 채우기(512토큰 묶음)의 top-k 도 한 블록(결정적)으로 바꾼 빌드. 실행마다 같은지 + 켬/끔이 같은지(진단, 감시기 없음):
#   t = top-k 만(FA 건너뛰기·키 직접 읽기 끔), tfg = 셋 다. tfg, t, tfg, t 순서로 깊이 8192·32768 1회씩, 같은 글 자리.
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; C=$R/fixcost/ctx-1112/corpus-llamacpp-e09a78a.txt
F=GGML_CUDA_NO_FA_SKIP=1; G=GGML_CUDA_NO_IDX_GATHER_FUSE=1
export SA_t="$F $G" SB_t="$F $G" SA_tfg="" SB_tfg=""
export SRV_EXTRA="-c 262144"
BENCH_S=900 WATCH=0 BENCH="tools/bench/ctx_bench.py $C 8192,32768 1 {OUT}/ctx.jsonl" \
  OUTDIR=longctx-1112 RUNS="none:tfg none:t none:tfg none:t" bash $R/tools/bench/node-ab.sh
for d in $(ls -1dtr $R/runs/srv-2node-none-bs-t*-1112-2* | tail -4); do echo "== $d"; grep -o '"depth": [0-9]*\|"sha": "[0-9a-f]*"\|"tg_ms": [0-9.]*' $d/ctx.jsonl | paste - - -; grep -c "crashed" $d/server.log; done
echo ALLDONE
