#!/usr/bin/env bash
# 11-14 (점검, 출력 그대로): QSA 마스크가 FA 타일에 주는 일 — 128k 깊이에서 A 노드 FA 마스크를 덤프(프리필 큰 묶음 8개, MTP 4토큰 검증 8개)하고
# tools/bench/masksim.py 로 (질의 타일 × KV 조각)별 계산 조각 비율과 질의 겹침을 본다. MTP 는 LLAMA_SPEC_MAX_CTX=0(전환 끔)이라 128k 에서도 검증을 한다.
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; C=$R/fixcost/ctx-1112/corpus-llamacpp-e09a78a.txt; MD=$R/runs/maskdump-1114
mkdir -p $MD
export SA_md="GGML_CUDA_FA_MASK_DUMP=$MD GGML_CUDA_FA_MASK_DUMP_MIN_KV=120000 GGML_CUDA_FA_MASK_DUMP_N=8" SB_md="" CL_md="LLAMA_SPEC_MAX_CTX=0"
SRV_EXTRA="-c 262144" BENCH_S=1500 WATCH=0 BENCH="tools/bench/ctx_bench.py $C 131072 1 {OUT}/ctx.jsonl" OUTDIR=maskdump-1114 \
  RUNS="mtp:md" bash $R/tools/bench/node-ab.sh
ls -la $MD
d=$(ls -1dtr $R/runs/srv-2node-mtp-bs-md-1114-* | tail -1); cat $d/ctx.jsonl; grep -c "Remote RPC server crashed" $d/server.log
echo ALLDONE
