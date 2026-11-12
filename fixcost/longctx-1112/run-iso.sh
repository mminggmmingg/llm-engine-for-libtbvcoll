#!/usr/bin/env bash
# 11-12 19:1x: run-lc1 의 lc 회가 깊이 32768 의 pp512 요청 시작에서 두 노드 GPU page fault. 세 변경을 하나씩만 켜고 같은 순서로(진단, 감시기 없음):
#   x1 = FA 건너뛰기만, x2 = 인덱서 키 직접 읽기만, x3 = top-k 한 블록만. 깊이 8192·32768 1회씩.
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; C=$R/fixcost/ctx-1112/corpus-llamacpp-e09a78a.txt
F=GGML_CUDA_NO_FA_SKIP=1; G=GGML_CUDA_NO_IDX_GATHER_FUSE=1; T=GGML_CUDA_NO_TOPK_1BLOCK=1
export SA_x1="$G $T" SB_x1="$G $T" SA_x2="$F $T" SB_x2="$F $T" SA_x3="$F $G" SB_x3="$F $G"
export SRV_EXTRA="-c 262144"
BENCH_S=900 WATCH=0 BENCH="tools/bench/ctx_bench.py $C 8192,32768 1 {OUT}/ctx.jsonl" \
  OUTDIR=longctx-1112 RUNS="${ISO_RUNS:-none:x1 none:x2 none:x3}" bash $R/tools/bench/node-ab.sh
for d in $(ls -1dtr $R/runs/srv-2node-none-bs-x[123]-1112-* | tail -3); do echo "== $d"; grep -o '"depth": [0-9]*\|"sha": "[0-9a-f]*"\|"tg_ms": [0-9.]*' $d/ctx.jsonl | paste - - -; grep -c "crashed" $d/server.log; done
echo ALLDONE
