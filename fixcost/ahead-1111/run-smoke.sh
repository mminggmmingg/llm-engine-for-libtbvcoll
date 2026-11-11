#!/usr/bin/env bash
# 11-11 07:3x: MTP 초안 미리 만들기(draft-ahead, LLAMA_SPEC_AHEAD) 첫 확인 — def / ah1(맞으면 씀) / ah2(만들기만, 비용·적중률) 한 회씩, 감시기 없이
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; O=$R/fixcost/ahead-1111
export BENCH_S=600 WATCH=0
# 로그는 덧붙임(서버마다 "S" 줄) — CL_ 값 안에 $(…) 를 넣으면 node-ab 의 eval echo 가 쪼개 클라이언트가 안 뜬다(07:38 첫 시도)
export CL_ah1="LLAMA_SPEC_AHEAD=1 LLAMA_SPEC_AHEAD_LOG=$O/log-ah1.txt"
export CL_ah2="LLAMA_SPEC_AHEAD=2 LLAMA_SPEC_AHEAD_LOG=$O/log-ah2.txt"
OUTDIR=ahead-1111 RUNS="${RUNS:-mtp:ah1 mtp:ah2}" bash $R/tools/bench/node-ab.sh
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1t $O/srv-2node-*-bench.txt)
grep -h "draft-ahead" $R/runs/srv-2node-mtp-bs-ah*/server.log | tail -4
