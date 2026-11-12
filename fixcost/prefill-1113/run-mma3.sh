#!/usr/bin/env bash
# 11-13 03:5x: 묶음 처리 FA 건너뛰기(기본 켬) 확인 — 1) 짧은 문맥 6 프롬프트 none·MTP(감시기 회 포함) 해시·속도 2) 64k·128k 켬/끔 한 쌍 더(순서 바꿈, 진단).
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; O=$R/fixcost/prefill-1113; C=$R/fixcost/ctx-1112/corpus-llamacpp-e09a78a.txt
export SA_mma="" SB_mma="" SA_nomma="GGML_CUDA_NO_FA_MMA_SKIP=1" SB_nomma="GGML_CUDA_NO_FA_MMA_SKIP=1"
BENCH_S=600 WATCH=1 OUTDIR=prefill-1113 RUNS="none:mma mtp:mma" bash $R/tools/bench/node-ab.sh
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1tr $O/srv-2node-*-mma*-1113-*-bench.txt | grep -v nomma | tail -4)
export SRV_EXTRA="-c 262144"
BENCH_S=2400 WATCH=0 BENCH="tools/bench/ctx_bench.py $C 65536,131072 1 {OUT}/ctx.jsonl" \
  OUTDIR=prefill-1113 RUNS="none:nomma none:mma" bash $R/tools/bench/node-ab.sh
for d in $(ls -1dtr $R/runs/srv-2node-none-bs-*mma-1113-* | tail -2); do echo "== $d"; python3 -I -c "
import json,sys
for l in open(sys.argv[1]):
    r=json.loads(l)
    print({k: r.get(k) for k in ('depth','off','ctx_ms','ctx_n','pp_ms','pp_n','tg_ms','sha')})" $d/ctx.jsonl; grep -c 'crashed\|wc error' $d/server.log; done
echo ALLDONE
