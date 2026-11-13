#!/usr/bin/env bash
# 11-14: 인덱서 키 전용 배열 켬(dn) / 끔(do, GGML_CUDA_NO_IDX_DENSE=1 = 11-13 의 캐시 행 직접 읽기) 번갈아, 깊이 32k·64k·128k(ctx_bench 1회씩, 같은 글 자리),
# none·MTP, 감시기 회 포함(사용자 규칙). 끝에 짧은 문맥 6 프롬프트 해시(켬).
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; C=$R/fixcost/ctx-1112/corpus-llamacpp-e09a78a.txt
export SA_dn="" SB_dn="" SA_do="GGML_CUDA_NO_IDX_DENSE=1" SB_do="GGML_CUDA_NO_IDX_DENSE=1"
SRV_EXTRA="-c 262144" BENCH_S=2400 WATCH=1 BENCH="tools/bench/ctx_bench.py $C 32768,65536,131072 1 {OUT}/ctx.jsonl" OUTDIR=idxdense-1114 \
  RUNS="none:dn none:do mtp:dn mtp:do" bash $R/tools/bench/node-ab.sh
BENCH_S=600 WATCH=0 OUTDIR=idxdense-1114 RUNS="none:dn mtp:dn" bash $R/tools/bench/node-ab.sh
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1tr $R/fixcost/idxdense-1114/srv-2node-*-dn-*-bench.txt | tail -2)
for d in $(ls -1dtr $R/runs/srv-2node-*-bs-d[no]*-1114-* | tail -12); do echo "== $d"; cat $d/ctx.jsonl 2>/dev/null; tail -1 $d/bench.txt; cat $d/stop.txt 2>/dev/null; done
echo ALLDONE
