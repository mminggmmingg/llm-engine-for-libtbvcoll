#!/usr/bin/env bash
# 11-12 14:5x: 사용자 "진지하게 컨텍스트 길이별로 우리 모델성능 한번 측정해보자" — llama-bench -d / llama-benchy 방식(tools/bench/ctx_bench.py):
# 깊이 0·4k·8k·16k·32k·64k·128k 에서 문맥 채우기(ctx_pp), pp512 @ d, tg128 @ d — 3회씩, none·MTP, 서버 -c 262144(모델 학습 길이).
# 감시기 회(WATCH=1)는 깊이 0·32k·128k 1회. 이어서 최대 깊이 260096(+512+128 = 260736 ≤ 262144) 1회씩(감시기 없음).
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; O=$R/fixcost/ctx-1112; C=$O/corpus-llamacpp-e09a78a.txt
sha256sum $C
export SRV_EXTRA="-c 262144"
BENCH_S=5400 WATCH=1 BENCH="tools/bench/ctx_bench.py $C 0,4096,8192,16384,32768,65536,131072 3 {OUT}/ctx.jsonl" \
  OUTDIR=ctx-1112 RUNS="none:ctx mtp:ctx" bash $R/tools/bench/node-ab.sh
BENCH_S=3600 WATCH=0 BENCH="tools/bench/ctx_bench.py $C 260096 1 {OUT}/ctx.jsonl" \
  OUTDIR=ctx-1112 RUNS="none:max mtp:max" bash $R/tools/bench/node-ab.sh
for d in $(ls -1dtr $R/runs/srv-2node-*-ctx-* $R/runs/srv-2node-*-max-* 2>/dev/null | tail -6); do echo "== $d"; sed -n '/^| depth/,/CTXDONE/p' $d/bench.txt; cat $d/stop.txt 2>/dev/null; done
echo ALLDONE
