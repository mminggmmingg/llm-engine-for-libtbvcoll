#!/usr/bin/env bash
# 11-12 22:1x: 긴 문맥 개선 확정 빌드(FA 가려진 묶음 건너뛰기, 인덱서 키 직접 읽기, 한 블록 top-k — 모두 기본 켬)로 README 의 컨텍스트 길이별 측정을 같은 조건으로 다시.
#   1) 깊이 0·4k·8k·16k·32k·64k·128k 3회씩, none·MTP, 감시기 회(0·32k·128k) 포함  2) 260096 1회씩  3) 짧은 문맥 기준 해시·속도(6 프롬프트)
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; O=$R/fixcost/longctx-1112; C=$R/fixcost/ctx-1112/corpus-llamacpp-e09a78a.txt
export SA_new="" SB_new=""
export SRV_EXTRA="-c 262144"
BENCH_S=5400 WATCH=1 BENCH="tools/bench/ctx_bench.py $C 0,4096,8192,16384,32768,65536,131072 3 {OUT}/ctx.jsonl" \
  OUTDIR=longctx-1112 RUNS="none:new mtp:new" bash $R/tools/bench/node-ab.sh
BENCH_S=3600 WATCH=0 BENCH="tools/bench/ctx_bench.py $C 260096 1 {OUT}/ctx.jsonl" \
  OUTDIR=longctx-1112 RUNS="none:newmax mtp:newmax" bash $R/tools/bench/node-ab.sh
unset SRV_EXTRA
BENCH_S=600 WATCH=0 OUTDIR=longctx-1112 RUNS="none:new mtp:new" bash $R/tools/bench/node-ab.sh
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1tr $O/srv-2node-*-new-*-bench.txt | tail -2)
for d in $(ls -1dtr $R/runs/srv-2node-*-new*-1112-* | tail -8); do echo "== $d"; sed -n '/^| depth/,/CTXDONE/p' $d/bench.txt; cat $d/stop.txt 2>/dev/null; done
echo ALLDONE
