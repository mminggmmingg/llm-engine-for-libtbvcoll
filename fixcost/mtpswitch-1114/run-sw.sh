#!/usr/bin/env bash
# 11-14: MTP 한 방향 전환(LLAMA_SPEC_MAX_CTX, 기본 65536) 확인 — 새 빌드, 감시기 회 포함(사용자 규칙).
#   sw = 기본(64k 부터 초안 없음). 깊이 0(초안)·64k·128k(초안 없음) — run-ab2 와 같은 글 자리(off 0·1024·2048)라 그 회의 MTP·none 값과 비교.
#   끝에 짧은 문맥 6 프롬프트(sw) 해시·속도.
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; C=$R/fixcost/ctx-1112/corpus-llamacpp-e09a78a.txt
export SA_sw="" SB_sw="" CL_sw=""
SRV_EXTRA="-c 262144" BENCH_S=2400 WATCH=1 BENCH="tools/bench/ctx_bench.py $C 0,65536,131072 1 {OUT}/ctx.jsonl" OUTDIR=mtpswitch-1114 \
  RUNS="mtp:sw" bash $R/tools/bench/node-ab.sh
BENCH_S=600 WATCH=0 OUTDIR=mtpswitch-1114 RUNS="mtp:sw" bash $R/tools/bench/node-ab.sh
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1tr $R/fixcost/mtpswitch-1114/srv-2node-mtp-bs-sw-1114-*-bench.txt | tail -1)
for d in $(ls -1dtr $R/runs/srv-2node-mtp-bs-sw*-1114-* | tail -3); do echo "== $d"; cat $d/ctx.jsonl 2>/dev/null; tail -1 $d/bench.txt; grep -h "LLAMA_SPEC_MAX_CTX" $d/server.log | head -2; grep -c "Remote RPC server crashed" $d/server.log; done
echo ALLDONE
