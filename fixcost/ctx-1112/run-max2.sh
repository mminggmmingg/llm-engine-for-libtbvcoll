#!/usr/bin/env bash
# 11-12 17:5x: run-ctx.sh 의 none 260096 회(srv-2node-none-bs-max-1112-170239)가 문맥 채우기 ≈16분째(17:20:36) 클라이언트↔B RPC RDMA 연결 오류
# ("RDMA CQ wc error: status=5 (Work Request Flushed Error)", "Remote RPC server crashed or returned malformed response")로 끊겨 같은 조건으로 한 번 다시.
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; O=$R/fixcost/ctx-1112; C=$O/corpus-llamacpp-e09a78a.txt
export SRV_EXTRA="-c 262144"
BENCH_S=3600 WATCH=0 BENCH="tools/bench/ctx_bench.py $C 260096 1 {OUT}/ctx.jsonl" \
  OUTDIR=ctx-1112 RUNS="none:max" bash $R/tools/bench/node-ab.sh
d=$(ls -1dt $R/runs/srv-2node-none-bs-max-* | head -1); echo "== $d"; sed -n '/^| depth/,/CTXDONE/p' $d/bench.txt; cat $d/stop.txt 2>/dev/null
echo ALLDONE
