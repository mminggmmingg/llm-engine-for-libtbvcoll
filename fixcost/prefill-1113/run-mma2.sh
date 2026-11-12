#!/usr/bin/env bash
# 11-13 03:1x: 묶음 처리 FA(MMA)에 가려진 KV 묶음 건너뛰기(fattn-mma-f16.cuh, 끄기 GGML_CUDA_NO_FA_MMA_SKIP=1) 둘째 확인(8k·16k·128k) — 진단(감시기 없음).
#   깊이 8192·32768 1회씩, 켬(mma)/끔(nomma). 같은 글 자리라 출력 sha 가 같아야 하고(긴 문맥 출력은 11-12 부터 결정적), 문맥 채우기·pp512 시간을 본다.
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; C=$R/fixcost/ctx-1112/corpus-llamacpp-e09a78a.txt
export SA_mma="" SB_mma="" SA_nomma="GGML_CUDA_NO_FA_MMA_SKIP=1" SB_nomma="GGML_CUDA_NO_FA_MMA_SKIP=1"
export SRV_EXTRA="-c 262144"
BENCH_S=2400 WATCH=0 BENCH="tools/bench/ctx_bench.py $C 8192,16384,131072 1 {OUT}/ctx.jsonl" \
  OUTDIR=prefill-1113 RUNS="${MMA_RUNS:-none:mma none:nomma}" bash $R/tools/bench/node-ab.sh
for d in $(ls -1dtr $R/runs/srv-2node-none-bs-*mma-1113-* | tail -2); do echo "== $d"; python3 -I -c "
import json,sys
for l in open(sys.argv[1]):
    r=json.loads(l)
    print({k: r.get(k) for k in ('depth','off','ctx_ms','ctx_n','pp_ms','pp_n','tg_ms','sha')})" $d/ctx.jsonl; grep -c 'crashed\|wc error' $d/server.log; done
echo ALLDONE
