#!/usr/bin/env bash
# 11-12 20:3x: FA 가 묶음 안의 가려진 행도 읽지 않게 한 빌드. tfg(새 기본) / t(top-k 만) 를 깊이 8192·32768·131072 1회씩(진단, 감시기 없음):
# 출력 sha 가 결정성 확인 회(run-det: 8192 0628b470…, 32768 fb7b1054…)와 같은지, 128k 에서 둘이 같은지, 그리고 속도.
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; C=$R/fixcost/ctx-1112/corpus-llamacpp-e09a78a.txt
F=GGML_CUDA_NO_FA_SKIP=1; G=GGML_CUDA_NO_IDX_GATHER_FUSE=1
export SA_t="$F $G" SB_t="$F $G" SA_tfg="" SB_tfg=""
export SRV_EXTRA="-c 262144"
BENCH_S=2400 WATCH=0 BENCH="tools/bench/ctx_bench.py $C 8192,32768,131072 1 {OUT}/ctx.jsonl" \
  OUTDIR=longctx-1112 RUNS="none:tfg none:t" bash $R/tools/bench/node-ab.sh
for d in $(ls -1dtr $R/runs/srv-2node-none-bs-t*-1112-2* | tail -2); do echo "== $d"; grep -o '"depth": [0-9]*\|"sha": "[0-9a-f]*"\|"tg_ms": [0-9.]*' $d/ctx.jsonl | paste - - -; grep -c "crashed" $d/server.log; done
echo ALLDONE
