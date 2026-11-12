#!/usr/bin/env bash
# 11-12 21:0x: FA 건너뛰기 두 판 — c = 묶음만(GGML_E2N_FA_SKIP_ROWS=0 빌드, bin-1112-chunk), r = 묶음 + 행(=1, bin-1112-rows).
# 깊이 32768·131072 1회씩, c r c r 번갈아(진단, 감시기 없음). 출력 sha 는 둘이 같아야 한다.
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; C=$R/fixcost/ctx-1112/corpus-llamacpp-e09a78a.txt
L=/data/parksThink/macos_reversing/codex/zbook-rdma/experiments/engine2n/llama.cpp/build-rocm3
export BIN_c=$L/bin-1112-chunk BIN_r=$L/bin-1112-rows
export SRV_EXTRA="-c 262144"
BENCH_S=2400 WATCH=0 BENCH="tools/bench/ctx_bench.py $C 32768,131072 1 {OUT}/ctx.jsonl" \
  OUTDIR=longctx-1112 RUNS="none:c none:r none:c none:r" bash $R/tools/bench/node-ab.sh
for d in $(ls -1dtr $R/runs/srv-2node-none-bs-[cr]-1112-2* | tail -4); do echo "== $d"; grep -o '"depth": [0-9]*\|"sha": "[0-9a-f]*"\|"tg_ms": [0-9.]*' $d/ctx.jsonl | paste - - -; grep -c "crashed" $d/server.log; done
echo ALLDONE
