#!/usr/bin/env bash
# 11-12 05:xx: LLAMA_QSA_SHORT 끔/켬 출력이 갈리는 자리의 1·2위 로그확률(tools/divergence.py, none, 진단). 04:0x 판은 프롬프트를 상대 경로로 줘서 바로 끝남.
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; O=$R/fixcost/watchfix-1112
export BENCH_S=900 WATCH=0 CL_v0="LLAMA_QSA_SHORT=0" CL_v1="LLAMA_QSA_SHORT=1"
BENCH="tools/divergence.py $R/eval/spec_prompts.json 256 $O/div-q0.jsonl" OUTDIR=watchfix-1112 RUNS="none:v0" bash $R/tools/bench/node-ab.sh
BENCH="tools/divergence.py $R/eval/spec_prompts.json 256 $O/div-q1.jsonl" OUTDIR=watchfix-1112 RUNS="none:v1" bash $R/tools/bench/node-ab.sh
python3 -I $R/tools/divergence.py diff $O/div-q0.jsonl $O/div-q1.jsonl
echo ALLDONE
