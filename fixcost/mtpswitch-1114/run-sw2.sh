#!/usr/bin/env bash
# 11-14 05:4x: run-sw 에서 문턱 뒤 초안 없는 MTP 서버가 none 서버보다 느렸다(128k 34.9 / 29.0 ms/토큰) — 초안 헤드가 토큰마다 계속 돌아서.
# 문턱 뒤 묶음은 헤드가 건너뛰게 고친 빌드로: (1) 구멍 시험 spec_hole.py(문턱 아래 짧은 요청이 긴 요청의 앞부분을 다시 쓸 때 초안 수가 같은지),
# (2) 깊이 0·64k·128k 속도 + 감시기 회(run-sw 와 같은 글 자리), (3) 짧은 문맥 6 프롬프트 해시.
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; C=$R/fixcost/ctx-1112/corpus-llamacpp-e09a78a.txt
export SA_sk="" SB_sk="" CL_sk=""
SRV_EXTRA="-c 262144" BENCH_S=1800 WATCH=0 BENCH="tools/bench/spec_hole.py $C {OUT}/hole.jsonl" OUTDIR=mtpswitch-1114 RUNS="mtp:sk" bash $R/tools/bench/node-ab.sh
SRV_EXTRA="-c 262144" BENCH_S=2400 WATCH=1 BENCH="tools/bench/ctx_bench.py $C 0,65536,131072 1 {OUT}/ctx.jsonl" OUTDIR=mtpswitch-1114 \
  RUNS="mtp:sk" bash $R/tools/bench/node-ab.sh
BENCH_S=600 WATCH=0 OUTDIR=mtpswitch-1114 RUNS="mtp:sk" bash $R/tools/bench/node-ab.sh
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1tr $R/fixcost/mtpswitch-1114/srv-2node-mtp-bs-sk-1114-*-bench.txt | tail -1)
for d in $(ls -1dtr $R/runs/srv-2node-mtp-bs-sk*-1114-* | tail -4); do echo "== $d"; cat $d/hole.jsonl $d/ctx.jsonl 2>/dev/null; tail -2 $d/bench.txt; grep -h "LLAMA_SPEC_MAX_CTX" $d/server.log | head -3; grep -c "Remote RPC server crashed" $d/server.log; done
echo ALLDONE
