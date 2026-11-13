#!/usr/bin/env bash
# 11-13 (진단, WATCH=0): 문맥 길이 표의 깊이 0 MTP(47.3 t/s, 주기 ≈54 ms)가 짧은 프롬프트(63.5 t/s, 주기 ≈46 ms)보다 느린 까닭 가르기.
#   서버 문맥 크기(-c 8192 기본 / -c 262144 = 표) × 글(6 프롬프트 / ctx_bench 깊이 0, 같은 글 자리 3곳)을 번갈아. 빌드 그대로(build-rocm3/bin).
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; C=$R/fixcost/ctx-1112/corpus-llamacpp-e09a78a.txt
for c in c8 c256 c8d0 c256d0; do export SA_$c="" SB_$c=""; done
B0="tools/bench/ctx_bench.py $C 0 3 {OUT}/ctx.jsonl"
ab() { BENCH_S=900 WATCH=0 OUTDIR=mtpctx-1113 bash $R/tools/bench/node-ab.sh; }
RUNS="mtp:c8" ab
SRV_EXTRA="-c 262144" RUNS="mtp:c256" ab
SRV_EXTRA="-c 262144" BENCH="$B0" RUNS="mtp:c256d0" ab
BENCH="$B0" RUNS="mtp:c8d0" ab
RUNS="none:c8" ab
SRV_EXTRA="-c 262144" RUNS="none:c256" ab
SRV_EXTRA="-c 262144" BENCH="$B0" RUNS="none:c256d0" ab
BENCH="$B0" RUNS="none:c8d0" ab
for d in $(ls -1dtr $R/runs/srv-2node-*-bs-c*-1113-* | tail -8); do echo "== $d"; cat $d/bench.txt | tail -12; cat $d/stop.txt 2>/dev/null; done
echo ALLDONE
