#!/usr/bin/env bash
# 11-12 18:4x: 긴 문맥 디코드 개선 첫 확인(진단, 감시기 없음). 같은 빌드에서
#   lo = 예전 경로(GGML_CUDA_NO_FA_SKIP=1 GGML_CUDA_NO_IDX_GATHER_FUSE=1 GGML_CUDA_NO_TOPK_1BLOCK=1), lc = 새 기본
# ctx_bench 깊이 8192·32768·131072 1회씩(같은 글 자리 → 출력 sha 를 회끼리 비교), 이어서 짧은 문맥 기준 해시(6 프롬프트, none·MTP).
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; O=$R/fixcost/longctx-1112; C=$R/fixcost/ctx-1112/corpus-llamacpp-e09a78a.txt
OFF="GGML_CUDA_NO_FA_SKIP=1 GGML_CUDA_NO_IDX_GATHER_FUSE=1 GGML_CUDA_NO_TOPK_1BLOCK=1"
export SA_lo="$OFF" SB_lo="$OFF" SA_lc="" SB_lc=""
export SRV_EXTRA="-c 262144"
BENCH_S=2400 WATCH=0 BENCH="tools/bench/ctx_bench.py $C 8192,32768,131072 1 {OUT}/ctx.jsonl" \
  OUTDIR=longctx-1112 RUNS="none:lo none:lc" bash $R/tools/bench/node-ab.sh
for d in $(ls -1dtr $R/runs/srv-2node-none-bs-l[oc]-1112-* | tail -2); do echo "== $d"; sed -n '/^| depth/,/CTXDONE/p' $d/bench.txt; cut -c1-400 $d/ctx.jsonl; done
unset SRV_EXTRA
BENCH_S=600 WATCH=0 OUTDIR=longctx-1112 RUNS="none:lc mtp:lc" bash $R/tools/bench/node-ab.sh
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1tr $O/srv-2node-*-lc-*-bench.txt | tail -2)
echo ALLDONE
