#!/usr/bin/env bash
# 11-12 14:4x (시험): ctx_bench.py 가 서버 캐시를 다시 쓰는지(둘째 요청 prompt_n = 512), n_predict 0 이 되는지 — 깊이 0·4096 한 번, none·MTP, -c 266240
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; O=$R/fixcost/ctx-1112
export BENCH_S=1800 WATCH=0 SRV_EXTRA="-c 266240" BENCH="tools/bench/ctx_bench.py $O/corpus-llamacpp-e09a78a.txt 0,4096 1 {OUT}/ctx.jsonl"
OUTDIR=ctx-1112 RUNS="${RUNS:-none:try mtp:try}" bash $R/tools/bench/node-ab.sh
for d in $(ls -1dtr $R/runs/srv-2node-*-try-* | tail -2); do echo "== $d"; cat $d/bench.txt; grep -iE "n_ctx|error|fail" $d/server.log | head -5; done
echo ALLDONE
